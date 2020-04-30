
@inline anytagged() = false
@inline anytagged(x::Tagged, args...) = true
@inline anytagged(x, args...) = anytagged(args...)


macro proptagcontext(name)
    quote
        Cassette.@context($name)

        ## promote(x,y) should not tag the output tuple with the union of tags
        ## of x and y. So here we recurse into promote, and then tag each
        ## element of the result with the original tag
        function Cassette.overdub(ctx::$name, f::typeof(promote), args...)
            promoted = Cassette.fallback(ctx, f, args...)

            # put the tags back on:
            tagged_promoted = map(args, promoted) do orig, prom
                if Cassette.hasmetadata(orig, ctx)
                    tag(prom, ctx, metadata(orig, ctx))
                else
                    prom
                end
            end
            Cassette.recurse(ctx, tuple, tagged_promoted...)
        end

        function Cassette.overdub(ctx::$name, f, args...)
            # this check can be inferred (in theory)
            if anytagged(args...)
                # This is a slower check
                if all(x->metatype(x, ctx) <: Cassette.NoMetaData, args)
                    if isleaf(f)
                        return Cassette.fallback(ctx, f, args...)
                    else
                        # there maybe closures closing over tagged values
                        return Cassette.recurse(ctx, f, args...)
                    end
                end
                if isleaf(f)
                    val = Cassette.fallback(ctx, f, args...)
                    return propagate_tags(ctx, f, val, args...)
                else
                    val = Cassette.recurse(ctx, f, args...)
                    # Inputs were tagged but the output wasn't
                    # So just leave the input tags on.
                    if !(val isa Tagged) || metatype(val, ctx) <: Cassette.NoMetaData
                        return propagate_tags(ctx, f, val, args...)
                    else
                        return val
                    end
                end
            else
                if isleaf(f)
                    return Cassette.fallback(ctx, f, args...)
                else
                    return Cassette.recurse(ctx, f, args...)
                end
            end
        end
    end |> esc
end


"""
`propagate_tags(ctx, f, result, args...)`

Called only if any of the `args` are Tagged.
must return `result` or a tagged version of `result`.
"""
@inline function propagate_tags(ctx, f, result, args...)
    result
end
