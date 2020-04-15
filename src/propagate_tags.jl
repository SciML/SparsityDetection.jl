
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
            promoted = Cassette.recurse(ctx, f, args...)

            # put the tags back on:
            tagged_promoted = map((x,v)->tag(v, ctx, metadata(x, ctx)), args, promoted)
            Cassette.overdub(ctx, tuple, tagged_promoted...)
        end

        function Cassette.overdub(ctx::$name, f, args...)
            # this check can be inferred (in theory)
            if anytagged(args...)
                # This is a slower check
                if !any(x->!(metatype(x, ctx) <: Cassette.NoMetaData), args)
                    return Cassette.recurse(ctx, f, args...)
                end
                val = Cassette.recurse(ctx, f, args...)

                # Inputs were tagged but the output wasn't
                if !(val isa Tagged)
                    return propagate_tags(ctx, f, val, args...)
                elseif metatype(val, ctx) <: Cassette.NoMetaData
                    return propagate_tags(ctx, f,
                                          val,
                                          args...)
                else
                    return val
                end
            else
                Cassette.recurse(ctx, f, args...)
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
