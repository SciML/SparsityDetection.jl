include("common.jl")

@testset "Jacobian Sparsity" begin include("jacobian.jl") end
@testset "Paraboloid example" begin include("paraboloid.jl") end
@testset "PDE with globals" begin include("global_PDE.jl") end

@testset "Hessian sparsity" begin include("hessian.jl") end

@testset "Exploration" begin include("ifsandbuts.jl") end
@testset "Examples" begin include("examples.jl") end
