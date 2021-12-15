export @pot

struct Pot
    pid::PotID
    tea_bag::Any
    resource_requirement::ResourceRequirement
end

function Pot(
    tea_bag;
    name=nameof(tea_bag),
    resource_requirement=ResourceRequirement(:cpu => eps(Float64))
)
    pid = name isa PotID ? name : PotID(name)
    Pot(tea_bag, pid, resource_requirement)
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
    ch::Channel{Any}
    create_time::DateTime
    last_update::DateTime
    n_processed::UInt
    taskref::Ref{Task}
end

_self() = get!(task_local_storage(), KEY, USER[*])
self() = _self().pid

Base.parent() = parent(self())

children() = children(self())
