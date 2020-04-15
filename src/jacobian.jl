## Data structure for tracking sparsity

"""
The sparsity pattern.

- `I`: Input index
- `J`: Ouput index

`(i, j)` means the `j`th element of the output depends on
the `i`th element of the input. Therefore `length(I) == length(J)`
"""
struct Sparsity
    m::Int
    n::Int
    I::Vector{Int} # Input
    J::Vector{Int} # Output
end

SparseArrays.sparse(s::Sparsity) = sparse(s.I, s.J, true, s.m, s.n)

Sparsity(m, n) = Sparsity(m, n, Int[], Int[])

function Base.push!(S::Sparsity, i::Int, j::Int)
    push!(S.I, i)
    push!(S.J, j)
end

struct ProvinanceSet
    set::Set{Int}
    ProvinanceSet(s::Set) = new(s)
    ProvinanceSet(s) = new(Set(s))
end

# note: this is not strictly set union, just some efficient way of concating
Base.union(p::ProvinanceSet, ::Cassette.NoMetaData) = p
Base.union(::Cassette.NoMetaData, p::ProvinanceSet) = p

Base.union(p::ProvinanceSet,
           q::ProvinanceSet) = ProvinanceSet(union(p.set, q.set))
Base.union(p::ProvinanceSet,
           q::ProvinanceSet,
           rs::ProvinanceSet...) = union(union(p, q), rs...)
Base.union(p::ProvinanceSet) = p

function Base.push!(S::Sparsity, i::Int, js::ProvinanceSet)
    for j in js.set
        push!(S, i, j)
    end
end

# Cassette

@proptagcontext JacobianSparsityContext

struct JacInput end
struct JacOutput end

const TagType = Union{JacInput,
                      JacOutput,
                      ProvinanceSet}

istainted(ctx::JacobianSparsityContext, val) = metatype(val, ctx) <: ProvinanceSet

Cassette.metadatatype(::Type{<:JacobianSparsityContext},
                      ::DataType) = TagType
# optimization
Cassette.metadatatype(::Type{<:JacobianSparsityContext},
                      ::Type{<:Number}) = ProvinanceSet

function propagate_tags(ctx::JacobianSparsityContext,
                        f, result, args...)

    # e.g. X .+ X[1]
    # XXX: This wouldn't be required if we didn't have Input
    #
    any(x->metatype(x, ctx) <: JacInput,
        args) && return result

    idxs = findall(args) do x
        metatype(x, ctx) <: ProvinanceSet
    end

    if isempty(idxs)
        return result
    else
        tag(untag(result, ctx),
            ctx,
            union(map(x->metadata(x, ctx), args[idxs])...))
    end
end
const TaggedOf{T} = Cassette.Tagged{A, T} where A

function Cassette.overdub(ctx::JacobianSparsityContext,
                          f::typeof(getindex),
                          X::Tagged,
                          idx::Union{TaggedOf{Int},Int}...)
    if metatype(X, ctx) <: JacInput
        i = LinearIndices(untag(X, ctx))[idx...]
        val = Cassette.fallback(ctx, f, X, idx...)
        tag(val, ctx, ProvinanceSet(i))
    else
        Cassette.recurse(ctx, f, X, idx...)
    end
end

# setindex! on the output
function Cassette.overdub(ctx::JacobianSparsityContext,
                          f::typeof(setindex!),
                          Y::Tagged,
                          val::Tagged,
                          idx::Int...)
    S = ctx.metadata[1]
    if metatype(Y, ctx) <: JacOutput
        set = metadata(val, ctx)
        if set isa ProvinanceSet
            i = LinearIndices(untag(Y, ctx))[idx...]
            push!(S, i, set)
        end
        Cassette.fallback(ctx, f, Y, val, idx...)
    else
        Cassette.recurse(ctx, f, Y, val, idx...)
    end
end

function jacobian_sparsity(f!, Y, X, args...;
                           sparsity=Sparsity(length(Y), length(X)),
                           verbose = true,
                           raw = false)

    ctx = JacobianSparsityContext(metadata=sparsity)
    ctx = Cassette.enabletagging(ctx, f!)
    ctx = Cassette.disablehooks(ctx)

    res = nothing
    abstract_run((result)->(res=result),
                 ctx,
                 f!,
                 tag(Y, ctx, JacOutput()),
                 tag(X, ctx, JacInput()),
                 map(arg -> arg isa Fixed ?
                     arg.value : tag(arg, ctx, ProvinanceSet(())), args)...;
                 verbose=verbose)

    if raw
        return (ctx, res)
    else
        return sparse(sparsity)
    end
end

function Cassette.overdub(ctx::JacobianSparsityContext,
                          f::typeof(Base.unsafe_copyto!),
                          X::Tagged,
                          xstart,
                          Y::Tagged,
                          ystart,
                          len)
    S = ctx.metadata[1]
    if metatype(Y, ctx) <: JacInput && metatype(X, ctx) <: JacOutput
        # Write directly to the output sparsity
        val = Cassette.fallback(ctx, f, X, xstart, Y, ystart, len)
        for (i, j) in zip(xstart:xstart+len-1, ystart:ystart+len-1)
            push!(S, i, j)
        end
        val
    elseif metatype(Y, ctx) <: JacInput
        # Keep around a ProvinanceSet
        val = Cassette.fallback(ctx, f, X, xstart, Y, ystart, len)
        nometa = Cassette.NoMetaMeta()
        rhs = (i->Cassette.Meta(ProvinanceSet(i), nometa)).(ystart:ystart+len-1)
        X.meta.meta[xstart:xstart+len-1] .= rhs
        val
    elseif metatype(X, ctx) <: JacOutput
        val = Cassette.fallback(ctx, f, X, xstart, Y, ystart, len)
        for (i, j) in zip(xstart:xstart+len-1, ystart:ystart+len-1)
            y = Cassette.@overdub ctx Y[j]
            set = metadata(y, ctx)
            if set isa ProvinanceSet
                push!(S, i, set)
            end
        end
        val
    else
        val = Cassette.fallback(ctx, f, X, xstart, Y, ystart, len)
        for (i, j) in zip(xstart:xstart+len-1, ystart:ystart+len-1)
            y = Cassette.@overdub ctx Y[j]
            set = metadata(y, ctx)
            nometa = Cassette.NoMetaMeta()
            X.meta.meta[i] = Cassette.Meta(set, nometa)
        end
        val
    end
end
