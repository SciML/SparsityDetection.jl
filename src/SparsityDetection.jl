module SparsityDetection

using SpecialFunctions
using Cassette, LinearAlgebra, SparseArrays
using Cassette: tag, untag, Tagged, metadata, hasmetadata, istagged, canrecurse
using Cassette: tagged_new_tuple, ContextTagged, BindingMeta, DisableHooks, nametype
using Core: SSAValue

export Sparsity, jacobian_sparsity, hessian_sparsity, hsparsity, sparsity!

include("util.jl")
include("controlflow.jl")
include("propagate_tags.jl")
include("linearity.jl")
include("jacobian.jl")
include("hessian.jl")
include("blas.jl")

Base.@deprecate sparsity!(args...) jacobian_sparsity(args...)
Base.@deprecate hsparsity(args...) hessian_sparsity(args...)

end
