#### Path

# First just do it for the case where there we assume
# tainted gotoifnots do not go in a loop!
# TODO: write a thing to detect this! (overdub predicates only in tainted ifs)
# implement snapshotting function state as an optimization for branch exploration
mutable struct Path
    path::BitVector
    cursor::Int
end

Path() = Path([], 1)

function increment!(bitvec)
    for i=1:length(bitvec)
        if bitvec[i] === true
            bitvec[i] = false
        else
            bitvec[i] = true
            break
        end
    end
end

function reset!(p::Path)
    p.cursor=1
    increment!(p.path)
    nothing
end

function alldone(p::Path) # must be called at the end of the function!
    all(identity, p.path)
end

function current_predicate!(p::Path)
    #bt = backtrace()
    #Base.show_backtrace(stdout, bt)
    if p.cursor > length(p.path)
        push!(p.path, false)
    else
        p.path[p.cursor]
    end
    val = p.path[p.cursor]
    p.cursor+=1
    val
end

alldone(c) = alldone(c.metadata[2])
reset!(c) = reset!(c.metadata[2])
current_predicate!(c) = current_predicate!(c.metadata[2])

#=
julia> p=Path()
Path(Bool[], 1)

julia> alldone(p) # must be called at the end of a full run
true

julia> current_predicate!(p)
false

julia> alldone(p) # must be called at the end of a full run
false

julia> current_predicate!(p)
false

julia> p
Path(Bool[false, false], 3)

julia> alldone(p)
false

julia> reset!(p)

julia> p
Path(Bool[true, false], 1)

julia> current_predicate!(p)
true

julia> current_predicate!(p)
false

julia> alldone(p)
false

julia> reset!(p)

julia> p
Path(Bool[false, true], 1)

julia> current_predicate!(p)
false

julia> current_predicate!(p)
true

julia> reset!(p)

julia> current_predicate!(p)
true

julia> current_predicate!(p)
true

julia> alldone(p)
true
=#

"""
`abstract_run(g, ctx, overdubbed_fn, args...)`

First rewrites every if statement

```julia
if <expr>
  ...
end

as

```julia
cond = <expr>
if istainted(ctx, cond) ? @amb(true, false) : cond
  ...
end
```

Then runs `g(Cassette.overdub(ctx, overdubbed_fn, args...)`
as many times as there are available paths. i.e. `2^n` ways
where `n` is the number of tainted branch conditions.

# Examples:
```
meta = Any[]
abstract_run(ctx, f. args...) do result
    push!(meta, metadata(result, ctx))
end
# do something to merge metadata from all the runs
```
"""
function abstract_run(acc, ctx::Cassette.Context, overdub_fn, args...; verbose=true)
    path = Path()
    pass_ctx = Cassette.similarcontext(ctx, metadata=(ctx.metadata, path), pass=AbsintPass)

    while true
        acc(Cassette.recurse(pass_ctx, ()->overdub_fn(args...)))

        verbose && println("Explored path: ", path)
        alldone(path) && break
        reset!(path)
    end
end

"""
`istainted(ctx, cond)`

Does `cond` have any metadata?
"""
function istainted(ctx, cond)
    error("Method needed: istainted(::$(typeof(ctx)), ::Bool)." *
          " See docs for `istainted`.")
end

# Must return 7 exprs
function rewrite_branch(ctx, stmt, extraslot, i)
    # turn
    #   gotoifnot %p #g 
    # into
    #   %t = istainted(%p)
    #   gotoifnot %t #orig
    #   %rec = @amb true false
    #   gotoifnot %rec #orig+1 (the next statement after gotoifnot)

    exprs = Any[]
    cond = stmt.args[1]        # already an SSAValue

    # insert a check to see if SSAValue(i) isa Tainted
    istainted_ssa = Core.SSAValue(i)
    push!(exprs, :($(Expr(:nooverdub, istainted))($(Expr(:contextslot)),
                              $cond)))

    # not tainted? jump to the penultimate statement
    push!(exprs, Expr(:gotoifnot, istainted_ssa, i+5))

    # tainted? then use current_predicate!(SSAValue(1))
    current_pred = i+2
    push!(exprs, :($(Expr(:nooverdub, current_predicate!))($(Expr(:contextslot)))))

    # Store the interpreter-provided predicate in the slot
    push!(exprs, Expr(:(=), extraslot, SSAValue(i+2)))

    push!(exprs, Core.GotoNode(i+6))

    push!(exprs, Expr(:(=), extraslot, cond))

    # here we put in the original code
    stmt1 = copy(stmt)
    stmt.args[1] = extraslot
    push!(exprs, stmt)

    exprs
end

function rewrite_ir(ctx, ref)
    # turn
    #   <val> ? t : f
    # into
    #   istainted(<val>) ? current_predicate!(p) : <val> ? t : f

    ir = ref.code_info
    ir = copy(ir)

    extraslot = gensym("tmp")
    push!(ir.slotnames, extraslot)
    push!(ir.slotflags, 0x00)
    extraslot = Core.SlotNumber(length(ir.slotnames))

    Cassette.insert_statements!(ir.code, ir.codelocs,
        (stmt, i) -> Base.Meta.isexpr(stmt, :gotoifnot) ? 7 : nothing, 
        (stmt, i) -> rewrite_branch(ctx, stmt, extraslot, i))

    ir.ssavaluetypes = length(ir.code)
    # Core.Compiler.validate_code(ir)
    #@show ref.method
    #@show ir
    return ir
end

const AbsintPass = Cassette.@pass rewrite_ir
