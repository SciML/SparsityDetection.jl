# Don't taint the value enclosed by Fixed
struct Fixed
    val
end

# Get the type of the metadata attached to a value
function metatype(x, ctx)
    if  istagged(x, ctx) && hasmetadata(x, ctx)
        typeof(metadata(x, ctx))
    else
        Cassette.NoMetaData
    end
end

# generic implementations

_name(x::Symbol) = x
_name(x::Expr) = (@assert x.head == :(::); x.args[1])
macro reroute(f, g)
    fname = f.args[1]
    fargs = f.args[2:end]
    gname = g.args[1]
    gargs = g.args[2:end]
    quote
        @inline function Cassette.overdub(ctx::JacobianSparsityContext,
                                          f::typeof($(esc(fname))),
                                          $(fargs...))
            Cassette.recurse(
                ctx,
                invoke,
                $(esc(gname)),
                $(esc(:(Tuple{$(gargs...)}))),
                $(map(_name, fargs)...))
        end

        @inline function Cassette.overdub(ctx::HessianSparsityContext,
                                          f::typeof($(esc(fname))),
                                          $(fargs...))
            Cassette.recurse(
                ctx,
                invoke,
                $(esc(gname)),
                $(esc(:(Tuple{$(gargs...)}))),
                $(map(_name, fargs)...))
        end
    end
end
