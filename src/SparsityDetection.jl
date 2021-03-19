"""
$(DocStringExtensions.README)
"""
module SparsityDetection

using DocStringExtensions
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

sparsity!(args...; kwargs...) = jacobian_sparsity(args...; kwargs...)
hsparsity(args...; kwargs...) = hessian_sparsity(args...; kwargs...)

end
