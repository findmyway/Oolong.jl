"""
Similar to `Future`, but we added some customized methods.
"""
struct Promise
    f::Future
    timeout::Float64
    function Promise(args...;timeout=3.0)
        new(Future(args...), timeout)
    end
end

function Base.getindex(p::Promise)
    c = Distributed.lookup_ref(Distributed.remoteref_id(p.f)).c
    timer = Timer(p.timeout) do t
        isready(c) || put!(c, TimeOutError(p.timeout))
    end
    v = p.f[]
    close(timer)
    if v isa TimeOutError
        throw(v)
    else
        v
    end
end

"Recursively fetch inner value"
function Base.getindex(p::Promise, ::typeof(*))
    x = p[]
    while x isa Promise
        x = x[]
    end
    x
end

function Base.getindex(ps::Vector{Promise})
    res = Vector(undef, length(ps))
    @sync for (i, p) in enumerate(ps)
        @async res[i] = p[]
    end
    res
end

Base.put!(p::Promise, x) = put!(p.f, x)
