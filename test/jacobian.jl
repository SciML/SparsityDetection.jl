import Base.Broadcast: broadcasted

let
    # Should this be Array{Tainted,1} ?
    @test jactestval((Y,X) -> typeof(X), [1], [2]) == Array{Int, 1}
    @test jactestval((Y,X) -> typeof(Y), [1], [2]) == Array{Int, 1}

    @test jactestval((Y,X) -> eltype(X), [1], [2]) == Int
    @test jactestval((Y,X) -> typeof(X[1]), [1], [2]) == Int
    @test jactestval((Y,X) -> typeof(X[1]/1), [1], [2]) == Float64

    f(y,x) = x .+ 1

    @test jactestval((Y,X) -> broadcasted(+, X, 1)[1], [1], [2]) == 3
    @test jactestval(f, [1], [2]) == [3]
    @test sparse(jactestmeta(f, [1], [2])) == sparse([], [], true, 1, 1)

    g(y,x) = y[:] .= x .+ 1
    #g(y,x) = y .= x .+ 1 -- memove

    println("Broadcast timings")
    println("  y .= x")
    # test path of unsafe_copy from Input to Output
    @test @time jacobian_sparsity((y,x) -> y .= x, [1,2,3], [1,2,3]) == sparse([1,2,3], [1,2,3], true)
    println("  y[:] .= x .+ 1")
    @test @time sparse(jactestmeta(g, [1], [2])) == sparse([1], [1], true)
    println("  y[1:2] .= x[2:3]")
    # test path of unsafe_copy from Input to an intermediary
    @test @time jacobian_sparsity((y,x) -> y[1:2] .= x[2:3], [1,2,3], [1,2,3]) == sparse([1,2],[2,3],true, 3,3)

    using LinearAlgebra, SparsityDetection

    function testsparse!(out, x)
        A = Tridiagonal(x[2:end], x, x[1:end-1])
        mul!(out, A, x)
    end
    x = [1:4;]; out = similar(x);
    @test jacobian_sparsity(testsparse!, out, x) == sparse([1,2,1,2,3,2,3,4,3,4],
                                                   [1,1,2,2,2,3,3,3,4,4], true)
end

@testset "BLAS" begin
    function f(out,in)
        A = rand(length(in), length(in))
        out .= A * in
        return nothing
    end

    x = [1.0:10;]
    out = similar(x)
    @test all(jacobian_sparsity(f, out, x) .== 1)
end

@testset "avoid branches in primitive functions with isleaf" begin
    # without the isleaf fix, this would go into an infinite loop
    # fixes issue #30
    x = rand(3)
    y = similar(x)
    function f(y, x)
        for i in 1:length(x)
            y[i] = exp(x[i])
        end
        return nothing
    end
    @test jacobian_sparsity(f, y, x) == sparse([1, 2, 3], [1, 2, 3], true)

    # this example tests that a function that gets tagged also indicates
    # isleaf correctly
    @test jacobian_sparsity(y,x) do y,x
        y .= exp.(x)
    end == sparse([1,2,3],[1,2,3],[1,1,1])
end
