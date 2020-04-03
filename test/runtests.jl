using SafeTestsets
include("common.jl")

@testset "Basics" begin include("basics.jl") end
@testset "Exploration" begin include("ifsandbuts.jl") end
@testset "Hessian sparsity" begin include("hessian.jl") end
@testset "Paraboloid example" begin include("paraboloid.jl") end
@safetestset "Global PDE example" begin include("global_PDE.jl") end
