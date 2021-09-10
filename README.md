# SparsityDetection.jl

#### Note: This repo has been deprecated in favor of [Symbolics.jl](https://github.com/JuliaSymbolics/Symbolics.jl) and [ModelingToolkit.jl](https://github.com/SciML/ModelingToolkit.jl) which can similarly inspect code and detect sparsity patterns.

[![Build Status](https://github.com/SciML/SparsityDetection.jl/workflows/CI/badge.svg)](https://github.com/SciML/SparsityDetection.jl/actions?query=workflow%3ACI)

This is a package for automatic Jacobian and Hessian sparsity pattern detection
on Julia functions. Functions written for numerical work can automatically be
investigated in order to understand and utilize sparsity. This does not work
numerically, and instead works by non-standard interpretation in order to
check every branch for connectivity in order to determine an accurate sparsity
pattern.

If you use this package, please cite the following:

```
@article{gowda2019sparsity,
  title={Sparsity Programming: Automated Sparsity-Aware Optimizations in Differentiable Programming},
  author={Gowda, Shashi and Ma, Yingbo and Churavy, Valentin and Edelman, Alan and Rackauckas, Christopher},
  year={2019}
}
```

## Example

Suppose we had the function

```julia
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
```

For this function, we know that the sparsity pattern of the Jacobian is a
`Tridiagonal` matrix. However, if we didn't know the sparsity pattern for
the Jacobian, we could use the `jacobian_sparsity` function to automatically
detect the sparsity pattern. This function is only available if you
load Cassette.jl as well. We declare that the function `f` outputs a
vector of length 30 and takes in a vector of length 30, and `jacobian_sparsity` spits
out a `Sparsity` object which we can turn into a `SparseMatrixCSC`:

```julia
using SparsityDetection, SparseArrays
input = rand(10)
output = similar(input)
sparsity_pattern = jacobian_sparsity(f,output,input)
jac = Float64.(sparse(sparsity_pattern))

```

## API

### Jacobian Sparsity

Automated Jacobian sparsity detection is provided by the `sparsity!` function.
The syntax is:

```julia
jacobian_sparsity(f, Y, X, args...; sparsity=Sparsity(length(X), length(Y)), verbose=true)
```

The arguments are:

- `f`: the function
- `Y`: the output array
- `X`: the input array
- `args`: trailing arguments to `f`. They are considered subject to change, unless wrapped as `Fixed(arg)`
- `S`: (optional) the sparsity pattern
- `verbose`: (optional) whether to describe the paths taken by the sparsity detection.

The function `f` is assumed to take arguments of the form `f(dx,x,args...)`.
`jacobian_sparsity` returns a `Sparsity` object which describes where the non-zeros
of the Jacobian occur. `sparse(::Sparsity)` transforms the pattern into
a sparse matrix.

This function utilizes non-standard interpretation, which we denote
combinatoric concolic analysis, to directly realize the sparsity pattern from
the program's AST. It requires that the function `f` is a Julia function. It
does not work numerically, meaning that it is not prone to floating point error
or cancelation. It allows for branching and will automatically check all of the
branches. However, a while loop of indeterminate length which is dependent
on the input argument is not allowed.

A similar method is now available from [Symbolics.jl](https://symbolics.juliasymbolics.org/stable/manual/sparsity_detection/#Sparsity-Detection-1).


### Hessian Sparsity

```julia
hessian_sparsity(f, X, args...; verbose=true)
```
The arguments are:

- `f`: the function
- `X`: the input array
- `args`: trailing arguments to `f`. They are considered subject to change, unless wrapped as `Fixed(arg)`
- `verbose`: (optional) whether to describe the paths taken by the sparsity detection.

The function `f` is assumed to take arguments of the form `f(x,args...)` and
returns a scalar.

This function utilizes non-standard interpretation, which we denote
combinatoric concolic analysis, to directly realize the sparsity pattern from
the program's AST. It requires that the function `f` is a Julia function. It
does not work numerically, meaning that it is not prone to floating point error
or cancelation. It allows for branching and will automatically check all of the
branches. However, a while loop of indeterminate length which is dependent
on the input argument is not allowed.
