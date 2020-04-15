using FiniteDiff, LinearAlgebra, Test
using SparsityDetection, SparseArrays

# Define the constants for the PDE
const α₂ = 1.0
const α₃ = 1.0
const β₁ = 1.0
const β₂ = 1.0
const β₃ = 1.0
const r₁ = 1.0
const r₂ = 1.0
const D = 100.0
const γ₁ = 0.1
const γ₂ = 0.1
const γ₃ = 0.1
const N = 8
const X = reshape([i for i in 1:N for j in 1:N],N,N)
const Y = reshape([j for i in 1:N for j in 1:N],N,N)
const α₁ = 1.0.*(X.>=4*N/5)

const Mx = Tridiagonal([1.0 for i in 1:N-1],[-2.0 for i in 1:N],[1.0 for i in 1:N-1])
const My = copy(Mx)
Mx[2,1] = 2.0
Mx[end-1,end] = 2.0
My[1,2] = 2.0
My[end,end-1] = 2.0

# Define the initial condition as normal arrays
u0 = zeros(N,N,3)

const MyA = zeros(N,N);
const AMx = zeros(N,N);
const DA = zeros(N,N);
# Define the discretized PDE as an ODE function
function f(du,u,p,t)
   A = @view  u[:,:,1]
   B = @view  u[:,:,2]
   C = @view  u[:,:,3]
  dA = @view du[:,:,1]
  dB = @view du[:,:,2]
  dC = @view du[:,:,3]
  mul!(MyA,My,A)
  mul!(AMx,A,Mx)
  @. DA = D*(MyA + AMx)
  @. dA = DA + α₁ - β₁*A - r₁*A*B + r₂*C
  @. dB = α₂ - β₂*B - r₁*A*B + r₂*C
  @. dC = α₃ - β₃*C + r₁*A*B - r₂*C
end

input = rand(N,N,3)
output = similar(input)
sparsity_pattern = jacobian_sparsity(f,output,input,nothing,0.0)
jac_sparsity = Float64.(sparse(sparsity_pattern))

function testf2(u)
	_u = reshape(u,size(input)...)
	du = similar(_u)
	f(du,_u,nothing,0.0)
	vec(du)
end
findifjac = FiniteDiff.finite_difference_jacobian(testf2,input)
@test all((abs.(findifjac) .> 0) .== (jac_sparsity .> 0))
