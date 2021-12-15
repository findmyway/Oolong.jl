"System level messages are processed immediately"
abstract type AbstractSysMsg end

is_prioritized(msg) = false
is_prioritized(msg::AbstractSysMsg) = true

# !!! force system level messages to be executed immediately
# directly copied from
# https://github.com/JuliaLang/julia/blob/6aaedecc447e3d8226d5027fb13d0c3cbfbfea2a/base/channels.jl#L13-L31
# with minor modification
function Base.put_buffered(c::Channel, v)
    lock(c)
    try
        while length(c.data) == c.sz_max
            Base.check_channel_state(c)
            wait(c.cond_put)
        end
        if is_prioritized(v)
            pushfirst!(c.data, v)  # !!! force sys msg to be handled immediately
        else
            push!(c.data, v)
        end
        # notify all, since some of the waiters may be on a "fetch" call.
        notify(c.cond_take, nothing, true, false)
    finally
        unlock(c)
    end
    return v
end

# !!! Current master branch of Julia changed the logic slightly
# TODO: add patch for new version
