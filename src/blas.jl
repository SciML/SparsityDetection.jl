# Forward BLAS calls to generic implementation
#
using LinearAlgebra
import LinearAlgebra.BLAS

# generic implementations

@reroute LinearAlgebra.BLAS.dot(x,y) LinearAlgebra.dot(Any, Any)
@reroute LinearAlgebra.BLAS.axpy!(x, y) LinearAlgebra.axpy!(Any,
                                                      AbstractArray,
                                                      AbstractArray)

gengemv!(tA, α, A, x, β, y) = LinearAlgebra.generic_matvecmul!(y, tA, A, x, LinearAlgebra.MulAddMul(α, β))

@reroute LinearAlgebra.BLAS.gemv!(tA, α, A, x, β, y) gengemv!(Any, Any, Any, Any, Any, Any)
