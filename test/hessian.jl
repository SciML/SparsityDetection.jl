
@test hesstestterms(x->x[1], [1,2]) == Term(1)

# Tuple / struct
@test hesstestterms(x->(x[1],x[2])[2], [1,2]) == Term(2)

@test hesstestterms(x->promote(x[1],convert(Float64, x[2]))[2], [1,2]) == Term(2)

# 1-arg linear
@test hesstestterms(x->deg2rad(x[1]), [1,2]) == Term(1)

# 1-arg nonlinear
@test hesstestterms(x->sin(x[1]), [1,2]) == (Term(1) + Term(1) * Term(1))

# 2-arg (true,true,true)
@test hesstestterms(x->x[1]+x[2], [1,2]) == Term(1)+Term(2)

# 2-arg (true,true, false)
@test hesstestterms(x->x[1]*x[2], [1,2]) == Term(1)*Term(2)

# 2-arg (true,false,false)
@test hesstestterms(x->x[1]/x[2], [1,2]) == Term(1)*Term(2)*Term(2)

# 2-arg (false,true,false)
@test hesstestterms(x->x[1]\x[2], [1,2]) == Term(1)*Term(1)*Term(2)

# 2-arg (false,false,false) 
@test hesstestterms(x->hypot(x[1], x[2]), [1,2]) == (Term(1) + Term(2)) * (Term(1) + Term(2))


### Array operations

# copy
@test hesstestterms(x->copy(x)[1], [1,2]) == Term(1)
@test hesstestterms(x->x[:][1], [1,2]) == Term(1)
@test hesstestterms(x->x[1:1][1], [1,2]) == Term(1)

# tests `iterate`
function mysum(x)
    s = 0
    for a in x
        s += a
    end
    s
end
@test hesstestterms(mysum, [1,2]).terms == (Term(1) + Term(2)).terms
@test hesstestterms(mysum, [1,2.]).terms == (Term(1) + Term(2)).terms

using LinearAlgebra

# integer dot product falls back to generic
@test hesstestterms(x->dot(x,x), [1,2,3]) == sum(Term(i)*Term(i) for i=1:3)

# reroutes to generic implementation (blas.jl)
@test hesstestterms(x->dot(x,x), [1,2,3.]) == sum(Term(i)*Term(i) for i=1:3)
@test hesstestterms(x->x'x, [1,2,3.]) == sum(Term(i)*Term(i) for i=1:3)

# broadcast
@test hesstestterms(x->sum(x[1] .+ x[2]), [1,2,3.]) == Term(1) + Term(2)
@test hesstestterms(x->sum(x .+ x), [1,2,3.]) == sum(Term(i) for i=1:3)
@test hesstestterms(x->sum(x .* x), [1,2,3.]) == sum(Term(i)*Term(i) for i=1:3)
