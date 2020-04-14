fcalls = 0
function f(dx,x)
  global fcalls += 1
  for i in 2:length(x)-1
    dx[i] = x[i-1] - 2x[i] + x[i+1]
  end
  dx[1] = -2x[1] + x[2]
  dx[end] = x[end-1] - 2x[end]
  nothing
end

using SparsityDetection, SparseArrays
input = rand(10)
output = similar(input)
sparsity_pattern = sparsity!(f,output,input)
jac = Float64.(sparse(sparsity_pattern))
