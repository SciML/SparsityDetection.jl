# SparsityDetection.jl

[![Build Status](https://travis-ci.org/JuliaDiffEq/SparsityDetection.jl.svg?branch=master)](https://travis-ci.org/JuliaDiffEq/SparsityDetection.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/iruuqu4hxq00vo3s?svg=true)](https://ci.appveyor.com/project/ChrisRackauckas/sparsitydetection-jl)

The ability to automatically detect the sparsity of a function would be great
right? That's what we do.

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
the Jacobian, we could use the `sparsity!` function to automatically
detect the sparsity pattern. This function is only available if you
load Cassette.jl as well. We declare that the function `f` outputs a
vector of length 30 and takes in a vector of length 30, and `sparsity!` spits
out a `Sparsity` object which we can turn into a `SparseMatrixCSC`:

```julia
using SparsityDetection
sparsity_pattern = sparsity!(f,output,input)
jac = Float64.(sparse(sparsity_pattern))
```

## API

Automated sparsity detection is provided by the `sparsity!` function. The syntax is:

```julia
`sparsity!(f, Y, X, args...; sparsity=Sparsity(length(X), length(Y)), verbose=true)`
```

The arguments are:

- `f`: the function
- `Y`: the output array
- `X`: the input array
- `args`: trailing arguments to `f`. They are considered subject to change, unless wrapped as `Fixed(arg)`
- `S`: (optional) the sparsity pattern
- `verbose`: (optional) whether to describe the paths taken by the sparsity detection.

The function `f` is assumed to take arguments of the form `f(dx,x,args...)`.
`sparsity!` returns a `Sparsity` object which describes where the non-zeros
of the Jacobian occur. `sparse(::Sparsity)` transforms the pattern into
a sparse matrix.

This function utilizes non-standard interpretation, which we denote
combinatoric concolic analysis, to directly realize the sparsity pattern from the program's AST. It requires that the function `f` is a Julia function. It does not
work numerically, meaning that it is not prone to floating point error or
cancelation. It allows for branching and will automatically check all of the
branches. However, a while loop of indeterminate length which is dependent
on the input argument is not allowed.
