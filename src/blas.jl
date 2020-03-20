# generic implementations

_name(x::Symbol) = x
_name(x::Expr) = (@assert x.head == :(::); x.args[1])
macro reroute(f, g)
    fname = f.args[1]
    fargs = f.args[2:end]
    quote
        @inline function Cassette.overdub(ctx::SparsityContext,
                                          f::typeof($(esc(fname))),
                                          $(fargs...))
            Cassette.recurse(
                ctx,
                invoke,
                f,
                $(esc(:(Tuple{$(g.args[2:end]...)}))),
                $(map(_name, fargs)...))
        end

        @inline function Cassette.overdub(ctx::HessianSparsityContext,
                                          f::typeof($(esc(fname))),
                                          args...)
            Cassette.recurse(
                ctx,
                invoke,
                $(esc(g.args[1])),
                $(esc(:(Tuple{$(g.args[2:end]...)}))),
                $(map(_name, fargs)...))
        end
    end
end

@reroute LinearAlgebra.BLAS.dot(x,y) LinearAlgebra.dot(Any, Any)
@reroute LinearAlgebra.BLAS.axpy!(x, y) LinearAlgebra.axpy!(Any,
                                                      AbstractArray,
                                                      AbstractArray)
@reroute LinearAlgebra.mul!(y::AbstractVector,
                            A::AbstractVecOrMat,
                            x::AbstractVector,
                            α::Number,
                            β::Number) LinearAlgebra.mul!(AbstractVector,
                                                          AbstractVecOrMat,
                                                          AbstractVector,
                                                          Number,
                                                          Number)
