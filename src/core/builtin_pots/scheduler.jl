const SCHEDULER = P"/sys/scheduler"

local_scheduler() = SCHEDULER / "local_scheduler_$(myid())"

abstract type AbstractPotRegistry end

const POT_REGISTRY = Dict{PotID, NamedTuple{(:pot, :children), Tuple{Pot, Set{PotID}}}}()

struct PotRegistry <: AbstractPotRegistry
end

function (r::PotRegistry)(op::Symbol, p::Pot)
    if op === :register
        POT_REGISTRY[p.pid] = p
        push!(POT_REGISTRY[parent(p.pid)].children, p.pid)
    elseif op === :rm
        pot, children = POT_REGISTRY[p.pid]
        for c in children
            r(op, c)
        end
        delete!(POT_REGISTRY, p.pid)
        stop(p.pid)
    else
        throw(ArgumentError("unknown operation: $op"))
    end
end

register(registry::PotRegistry, p::Pot) = REGISTRY(:register, p)
Base.rm(registry::PotRegistry, p::Pot) = REGISTRY(:rm, p)

######

abstract type AbstractPotStore end

const POT_STORE = Dict{PotID, RemoteChannel{Channel{Any}}}()

"""
Local cache on each worker to reduce remote call.
The reference may be staled.
"""
const LOCAL_POT_STORE = Dict{PotID, RemoteChannel{Channel{Any}}}()

struct PotStore
end

function (p::PotStore)(op, arg)
    if op === :set
        k, v = arg
        POT_STORE[k] = v
    elseif op === :deleted!
        delete!(POT_STORE, arg)
    else
        throw(ArgumentError("unknown operation: $op"))
    end
end

Base.setindex!(p::PotStore, v::RemoteChannel, k::PotID) = get!(LOCAL_POT_STORE, k, POT_STORE(:set, k => v))

function Base.delete!(p::PotStore, k::PotID)
    delete!(LOCAL_POT_STORE, k)
    POT_STORE(:delete, k)
end

whereis(p::PotID) = p[].where

function Base.getindex(p::PotID, ::typeof(!))
    pot = remotecall_wait(1) do
        get(Oolong.POT_REGISTRY, p, nothing)
    end
    if isnothing(pot[])
        throw(PotNotRegisteredError(p))
    else
        pot[]
    end
end

"""
For debug only. Only a snapshot is returned.
!!! DO NOT MODIFY THE RESULT DIRECTLY
"""
Base.getindex(p::PotID, ::typeof(*)) = p(_self())[]

local_boil(p::PotID) = local_boil(p[!])

function local_boil(p::Pot)
    pid, tea_bag, logger = p.pid, p.tea_bag, p.logger
    ch = RemoteChannel() do
        Channel(typemax(Int),spawn=true) do ch
            task_local_storage(KEY, PotState(pid, current_task()))
            with_logger(logger) do
                tea = tea_bag()
                while true
                    try
                        flavor = take!(ch)
                        process(tea, flavor)
                        if flavor isa CloseMsg || flavor isa RemoveMsg
                            break
                        end
                    catch err
                        @debug err
                        flavor = parent()(err)[]
                        if msg isa ResumeMsg
                            process(tea, flavor)
                        elseif msg isa CloseMsg
                            process(tea, flavor)
                            break
                        elseif msg isa RestartMsg
                            process(tea, PreRestartMsg())
                            tea = tea_bag()
                            process(tea, PostRestartMsg())
                        else
                            @error "unknown msg received from parent: $exec"
                            rethrow()
                        end
                    finally
                    end
                end
            end
        end
    end
    link(pid, ch)
    ch
end

"blocking until a valid channel is established"
boil(p::PotID) = local_scheduler()(p)[!]

struct CPUInfo
    total_threads::Int
    allocated_threads::Int
    total_memory::Int
    free_memory::Int
    function CPUInfo()
        new(
            Sys.CPU_THREADS,
            Threads.nthreads(),
            convert(Int, Sys.total_memory()),
            convert(Int, Sys.free_memory()),
        )
    end
end

struct GPUInfo
    name::String
    total_memory::Int
    free_memory::Int
    function GPUInfo()
        new(
            name(device()),
            CUDA.total_memory(),
            CUDA.available_memory()
        )
    end
end

struct ResourceInfo
    cpu::CPUInfo
    gpu::Vector{GPUInfo}
end

function ResourceInfo()
    cpu = CPUInfo()
    gpu = []
    if CUDA.functional()
        for d in devices()
            device!(d) do
                push!(gpu, GPUInfo())
            end
        end
    end
    ResourceInfo(cpu, gpu)
end

Base.convert(::Type{ResourceInfo}, r::ResourceInfo) = ResourceInfo(r.cpu.allocated_threads, length(r.gpu))

struct HeartBeat
    resource::ResourceInfo
    available::ResourceInfo
    from::PotID
end

struct LocalScheduler
    pending::Dict{PotID, Future}
    peers::Ref{Dict{PotID, ResourceInfo}}
    available::Ref{ResourceInfo}
    timer::Timer
end

# TODO: watch exit info

function LocalScheduler()
    pid = self()
    req = convert(ResourceInfo, ResourceInfo())
    available = Ref(req)
    timer = Timer(1;interval=1) do t
        HeartBeat(ResourceInfo(), available[], pid) |> SCHEDULER  # !!! non blocking
    end

    pending = Dict{PotID, Future}()
    peers = Ref(Dict{PotID, ResourceInfo}(pid => req))

    LocalScheduler(pending, peers, available, timer)
end

function (s::LocalScheduler)(p::PotID)
    pot = p[!]
    if pot.require <= s.available[]
        res = local_boil(p)
        s.available[] -= pot.require
        res
    else
        res = Future()
        s.pending[p] = res
        res
    end
end

function (s::LocalScheduler)(peers::Dict{PotID, ResourceInfo})
    s.peers[] = peers
    for (p, f) in s.pending
        pot = p[!]
        for (w, r) in peers
            if pot.require <= r
                # transfer to w
                put!(f, w(p))
                delete!(s.pending, p)
                break
            end
        end
    end
end

Base.@kwdef struct Scheduler
    workers::Dict{PotID, HeartBeat} = Dict()
    pending::Dict{PotID, Future} = Dict()
end

# ??? throttle
function (s::Scheduler)(h::HeartBeat)
    # ??? TTL
    s.workers[h.from] = h

    for (p, f) in s.pending
        pot = p[!]
        if pot.require <= h.available
            put!(f, h.from(p))
        end
    end

    Dict(
        p => h.available
        for (p, h) in s.workers
    ) |> h.from  # !!! non blocking
end

# pots are all scheduled on workers only
function (s::Scheduler)(p::PotID)
    pot = p[!]
    for (w, h) in s.workers
        if pot.require <= h.available
            return w(p)
        end
    end
    res = Future()
    s.pending[p] = res
    res
end


