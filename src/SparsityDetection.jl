module SparsityDetection

using SpecialFunctions
using Cassette, LinearAlgebra, SparseArrays
using Cassette: tag, untag, Tagged, metadata, hasmetadata, istagged, canrecurse
using Cassette: tagged_new_tuple, ContextTagged, BindingMeta, DisableHooks, nametype
using Core: SSAValue

export Sparsity, hsparsity, sparsity!

include("program_sparsity.jl")
include("sparsity_tracker.jl")
include("path.jl")
include("take_all_branches.jl")
include("terms.jl")
include("linearity.jl")
include("hessian.jl")
include("blas.jl")
include("linearity_special.jl")

end
