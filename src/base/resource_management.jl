"""
    ResourceRequirement([tag => value]...)

Used to claim the required resource of a [`Pot`](@ref).
For example: `ResourceRequirement(:cpu => 1)`

See also [`ResourceStatus`](@ref), [`ResourceCollector`](@ref).
"""
struct ResourceRequirement{T<:NamedTuple}
    info::T
end

ResourceRequirement(args::Pair...) = ResourceRequirement(NamedTuple(args))

"""
    ResourceStatus([tag => value])

Represent the current status of the worker node.
For example: `ResourceStatus(:cpu => 2, :gpu => 1)`
"""
struct ResourceStatus{T<:NamedTuple}
    status::T
end

ResourceStatus(args::Pair...) = ResourceStatus(NamedTuple(args))

function Base.:(-)(rs::ResourceStatus, rr::ResourceRequirement)
    updated_status = rs.status
    for k in keys(rr.info)
        if haskey(rs.status, k)
            if rs.status[k] >= rr.info[k]
                updated_status = merge(updated_status, (;k => rs.status[k] - rr.info[k]))
            else
                throw(RequirementNotSatisfiedError(k, rr.info[k], rs.status[k]))
            end
        else
            throw(RequirementNotSatisfiedError(k, rr.info[k], nothing))
        end
    end
    ResourceStatus(updated_status)
end

function Base.:(+)(rs::ResourceStatus, rr::ResourceRequirement)
    updated_status = rs.status
    for (k,v) in pairs(rr.info)
        updated_status = merge(updated_status, (;k => v + get(updated_status, k, zero(v))))
    end
    ResourceStatus(updated_status)
end

"""
    ResourceCollector([tag => collector]...)

Each `collector` is a parameterless function and should return a measurement.
It will be called at the start of a worker.
"""
struct ResourceCollector{T<:NamedTuple}
    collectors::T
end

ResourceCollector(args::Pair...) = ResourceCollector(NamedTuple(args))

"""
    (c::ResourceCollector)()

Return a [`ResourceStatus`](@ref)
"""
(c::ResourceCollector)() = ResourceStatus(map(f -> f(), c.collectors))
