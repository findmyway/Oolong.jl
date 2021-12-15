export @P_str

struct PotID{N}
    path::NTuple{N,Symbol}
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
    print(io, "P\"")
    if isempty(getfield(p, :path))
        print(io, "/")
    else
        for x in getfield(p, :path)
            print(io, '/')
            print(io, x)
        end
    end
    print(io, "\"")
end

function PotID(s::String)
    if length(s) > 0
        if s[1] == '/'
            PotID(Tuple(Symbol(x) for x in split(s, '/'; keepempty = false)))
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

Base.parent(p::PotID) = PotID(getfield(p, :path)[1:end-1])
Base.hash(x::PotID, h) = hash(x.path, h)
Base.isequal(x::PotID, y::PotID) = isequal(x.path, y.path)
