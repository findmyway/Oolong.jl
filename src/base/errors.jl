#####

struct PotNotRegisteredError <: Exception
    pid::PotID
end

Base.showerror(io::IO, err::PotNotRegisteredError) = print(io, "can not find any pot associated with the pid: $(err.pid)")

#####

struct PotNotBoiledError <: Exception
    pid::PotID
end

Base.showerror(io::IO, err::PotNotBoiledError) = print(io, "can not find any boiled pot instance associated with the pid: $(err.pid)")

#####

struct RequirementNotSatisfiedError <: Exception
    resource_tag::Symbol
    required::Any
    available::Any
end

Base.showerror(io::IO, err::RequirementNotSatisfiedError) = print(io, "required resource of $(err.resource_tag) is not satisfied. Required: $(err.required). Available: $(err.available)")

#####

struct TimeOutError <: Exception
    t::Float64
end

Base.showerror(io::IO, err::TimeOutError) = print(io, "failed to complete in $(err.t) seconds")
