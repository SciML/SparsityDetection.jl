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

# Tags:
struct Input end
struct Output end

struct ProvinanceSet{T<:Set}
    set::T # Set, Array, Int, Tuple, anything!
end

# note: this is not strictly set union, just some efficient way of concating
Base.union(p::ProvinanceSet,
           q::ProvinanceSet) = ProvinanceSet(union(p.set, q.set))
Base.union(p::ProvinanceSet,
           q::ProvinanceSet,
           rs::ProvinanceSet...) = union(union(p, q), rs...)
Base.union(p::ProvinanceSet) = p

pset(x...) = ProvinanceSet(Set([x...]))

function Base.push!(S::Sparsity, i::Int, js::ProvinanceSet)
    for j in js.set
        push!(S, i, j)
    end
end

Cassette.@context SparsityContext

const TagType = Union{Input, Output, ProvinanceSet}
Cassette.metadatatype(::Type{<:SparsityContext}, ::DataType) = TagType

metatype(x, ctx) = hasmetadata(x, ctx) && istagged(x, ctx) && typeof(metadata(x, ctx))
function ismetatype(x, ctx, T)
    hasmetadata(x, ctx) && istagged(x, ctx) && (metadata(x, ctx) isa T)
end

# Dummy type when you getindex
struct Tainted end

# getindex on the input
@inline function Cassette.overdub(ctx::SparsityContext,
                                  f::typeof(getindex),
                                  X::Tagged,
                                  idx::Int...)
    if ismetatype(X, ctx, Input)
        i = LinearIndices(untag(X, ctx))[idx...]
        val = Cassette.fallback(ctx, f, X, idx...)
        tag(val, ctx, pset(i))
    else
        Cassette.recurse(ctx, f, X, idx...)
    end
end

# setindex! on the output
@inline function Cassette.overdub(ctx::SparsityContext,
                                  f::typeof(setindex!),
                                  Y::Tagged,
                                  val::Tagged,
                                  idx::Int...)
    S, path = ctx.metadata
    if ismetatype(Y, ctx, Output)
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

function get_provinance(ctx, arg::Tagged)
    if metadata(arg, ctx) isa ProvinanceSet
        metadata(arg, ctx)
    else
        pset()
    end
end

get_provinance(ctx, arg) = pset()

# Any function acting on a value tagged with ProvinanceSet
function _overdub_union_provinance(ctx::SparsityContext, f, args...) where {eval}
    idxs = findall(x->ismetatype(x, ctx, ProvinanceSet), args)
    if isempty(idxs)
        Cassette.recurse(ctx, f, args...)
    else
        provinance = union(map(arg->get_provinance(ctx, arg), args[idxs])...)
        val = Cassette.recurse(ctx, f, args...)
        if ismetatype(val, ctx, ProvinanceSet)
            tag(untag(val, ctx), ctx, union(metadata(val, ctx), provinance))
        else
            tag(val, ctx, provinance)
        end
    end
end

function Cassette.overdub(ctx::SparsityContext, f, args...)
    haspsets = false
    hasinput = false
    hasoutput = false

    for a in args
        if ismetatype(a, ctx, ProvinanceSet)
            haspsets = true
        elseif ismetatype(a, ctx, Input)
            hasinput = true
        elseif ismetatype(a, ctx, Output)
            hasoutput = true
        end
    end

    if haspsets && !hasinput && !hasoutput
        return _overdub_union_provinance(ctx, f, args...)
    else
        return Cassette.recurse(ctx, f, args...)
    end
end

function Cassette.overdub(ctx::SparsityContext,
                          f::typeof(Base.unsafe_copyto!),
                          X::Tagged,
                          xstart,
                          Y::Tagged,
                          ystart,
                          len)
    S = ctx.metadata[1]
    if ismetatype(Y, ctx, Input) && ismetatype(X, ctx, Output)
        # Write directly to the output sparsity
        val = Cassette.fallback(ctx, f, X, xstart, Y, ystart, len)
        for (i, j) in zip(xstart:xstart+len-1, ystart:ystart+len-1)
            push!(S, i, j)
        end
        val
    elseif ismetatype(Y, ctx, Input)
        # Keep around a ProvinanceSet
        val = Cassette.fallback(ctx, f, X, xstart, Y, ystart, len)
        nometa = Cassette.NoMetaMeta()
        rhs = (i->Cassette.Meta(pset(i), nometa)).(ystart:ystart+len-1)
        X.meta.meta[xstart:xstart+len-1] .= rhs
        val
    elseif ismetatype(X, ctx, Output)
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

#=
# Examples:
#
using UnicodePlots

sspy(s::Sparsity) = spy(sparse(s))

julia> sparsity!([0,0,0], [23,53,83]) do Y, X
           Y[:] .= X
           Y == X
       end
(true, Sparsity([1, 2, 3], [1, 2, 3]))

julia> sparsity!([0,0,0], [23,53,83]) do Y, X
           for i=1:3
               for j=i:3
                   Y[j] += X[i]
               end
           end; Y
       end
([23, 76, 159], Sparsity(3, 3, [1, 2, 3, 2, 3, 3], [1, 1, 1, 2, 2, 3]))

julia> sspy(ans[2])
     Sparsity Pattern
     ┌─────┐
   1 │⠀⠄⠀⠀⠀│ > 0
   3 │⠀⠅⠨⠠⠀│ < 0
     └─────┘
     1     3
     nz = 6

julia> sparsity!(f, zeros(Int, 3,3), [23,53,83])
([23, 53, 83], Sparsity(9, 3, [2, 5, 8], [1, 2, 3]))

julia> sspy(ans[2])
     Sparsity Pattern
     ┌─────┐
   1 │⠀⠄⠀⠀⠀│ > 0
     │⠀⠀⠠⠀⠀│ < 0
   9 │⠀⠀⠀⠐⠀│
     └─────┘
     1     3
     nz = 3
=#
