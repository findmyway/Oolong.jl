export @P_str, @pot

struct PotID
    path::Tuple{Vararg{Symbol}}
end

"""
    P"[/]your/pot/path"

The path can be either relative or absolute path. If a relative path is provided, it will be resolved to an absolute path based on the current context.

!!! note
    We don't validate the path for you during construction. A [`PotNotRegisteredError`](@ref) will be thrown when you try to send messages to an unregistered path.
"""
macro P_str(s)
    PotID(s)
end

function Base.show(io::IO, p::PotID)
    if isempty(getfield(p, :path))
        print(io, "/")
    else
        for x in getfield(p, :path)
            print(io, '/')
            print(io, x)
        end
    end
end

function PotID(s::String)
    if length(s) > 0
        if s[1] == '/'
            PotID(Tuple(Symbol(x) for x in split(s, '/';keepempty=false)))
        else
            self() / s
        end
    else
        PotID(())
    end
end

function Base.:(/)(p::PotID, s::String)
    PotID((getfield(p, :path)..., Symbol(s)))
end

const ROOT = P"/"
const LOGGER = P"/log"
const SCHEDULER = P"/scheduler"
const USER = P"/user"
struct Pot
    tea_bag::Any
    pid::PotID
    required_resource::ResourceInfo
end

function Pot(
    tea_bag;
    name=nameof(tea_bag),
    required_resource=ResourceInfo(cpu=eps())
)
    pid = name isa PotID ? name : PotID(name)
    Pot(tea_bag, pid, required_resource)
end

macro pot(tea, kw...)
    tea_bag = esc(:(() -> ($(tea))))
    xs = [esc(x) for x in kw]
    quote
        p = Pot($tea_bag; $(xs...))
        register(p)
        p.pid
    end
end

mutable struct PotState
    pid::PotID
    ch::Channel
    create_time::DateTime
    last_update::DateTime
    n_processed::UInt
end

_self() = get!(task_local_storage(), KEY, USER[*])
self() = _self().pid

local_scheduler() = SCHEDULER/"local_scheduler_$(myid())"

Base.parent() = parent(self())
Base.parent(p::PotID) = PotID(getfield(p, :path[1:end-1]))

children() = children(self())
