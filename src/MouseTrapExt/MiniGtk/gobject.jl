const GObject = Ptr{Nothing}
const  AbstractStringLike = Union{AbstractString, Symbol}
bytestring(s) = String(s)
bytestring(s::Symbol) = s
bytestring(s::Ptr{UInt8}) = unsafe_string(s)

const gc_preserve = Dict{Any, Tuple{Int, Int}}() # reference counted closures
const gc_map = Dict{Int, Any}()
function gc_ref(@nospecialize(x))
    global gc_preserve
    local id::Int, ref::Int
    if x in keys(gc_preserve)
        id, ref = gc_preserve[x]
    else
        id = 1
        while haskey(gc_map, id)
            id += 1
        end
        ref = 0
    end
    gc_preserve[x] = (id, ref + 1)
    gc_map[id] = x
    return id
end
function gc_unref(@nospecialize(x))
    global gc_preserve
    id, ref = gc_preserve[x]
    if ref == 1
        delete!(gc_preserve, x)
        delete!(gc_map, id)
    else
        gc_preserve[x] = (id, ref - 1)
    end
    nothing
end

gc_get(id) = gc_map[id]