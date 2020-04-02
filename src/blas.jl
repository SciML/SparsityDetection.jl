# generic implementations

_name(x::Symbol) = x
_name(x::Expr) = (@assert x.head == :(::); x.args[1])
macro reroute(f, g)
    fname = f.args[1]
    fargs = f.args[2:end]
    gname = g.args[1]
    gargs = g.args[2:end]
    quote
        @inline function Cassette.overdub(ctx::SparsityContext,
                                          f::typeof($(esc(fname))),
                                          $(fargs...))
            Cassette.recurse(
                ctx,
                invoke,
                $(esc(gname)),
                $(esc(:(Tuple{$(gargs...)}))),
                $(map(_name, fargs)...))
        end

        @inline function Cassette.overdub(ctx::HessianSparsityContext,
                                          f::typeof($(esc(fname))),
                                          $(fargs...))
            Cassette.recurse(
                ctx,
                invoke,
                $(esc(gname)),
                $(esc(:(Tuple{$(gargs...)}))),
                $(map(_name, fargs)...))
        end
    end
end

@reroute LinearAlgebra.BLAS.dot(x,y) LinearAlgebra.dot(Any, Any)
@reroute LinearAlgebra.BLAS.axpy!(x, y) LinearAlgebra.axpy!(Any,
                                                      AbstractArray,
                                                      AbstractArray)

gengemv!(tA, α, A, x, β, y) = LinearAlgebra.generic_matvecmul!(y, tA, A, x, LinearAlgebra.MulAddMul(α, β))

@reroute LinearAlgebra.BLAS.gemv!(tA, α, A, x, β, y) gengemv!(Any, Any, Any, Any, Any, Any)
