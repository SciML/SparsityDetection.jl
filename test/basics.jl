using LinearAlgebra

let
    # Should this be Array{Tainted,1} ?
    @test testval((Y,X) -> typeof(X), [1], [2]) == Array{Int, 1}
    @test testval((Y,X) -> typeof(Y), [1], [2]) == Array{Int, 1}

    @test testval((Y,X) -> eltype(X), [1], [2]) == Int
    @test testval((Y,X) -> typeof(X[1]), [1], [2]) == Int
    @test testval((Y,X) -> typeof(X[1]/1), [1], [2]) == Float64

    f(y,x) = x .+ 1

    @test testval((Y,X) -> broadcasted(+, X, 1)[1], [1], [2]) == 3
    @test testval(f, [1], [2]) == [3]
    @test sparse(testmeta(f, [1], [2])[1]) == sparse([], [], true, 1, 1)

    g(y,x) = y[:] .= x .+ 1
    #g(y,x) = y .= x .+ 1 -- memove

    @test sparse(testmeta(g, [1], [2])[1]) == sparse([1], [1], true)
    # test path of unsafe_copy from Input to Output
    @test sparsity!((y,x) -> y .= x, [1,2,3], [1,2,3]) == sparse([1,2,3], [1,2,3], true)
    # test path of unsafe_copy from Input to an intermediary
    @test sparsity!((y,x) -> y[1:2] .= x[2:3], [1,2,3], [1,2,3]) == sparse([1,2],[2,3],true, 3,3)

    using LinearAlgebra, SparsityDetection

    function testsparse!(out, x)
        A = Tridiagonal(x[2:end], x, x[1:end-1])
        mul!(out, A, x)
    end
    x = [1:4;]; out = similar(x);
    @test sparsity!(testsparse!, out, x) == sparse([1,2,1,2,3,2,3,4,3,4],
                                                   [1,1,2,2,2,3,3,3,4,4], true)
end

