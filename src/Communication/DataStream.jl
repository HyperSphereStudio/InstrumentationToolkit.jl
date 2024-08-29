using DataStructures

export DataStreamIO, writespaceavailable, skipuntil

struct DataStreamIO <: IO
    buf::CircularBuffer{UInt8}
    ref::Vector{UInt8}

    function DataStreamIO(; capacity=1000)
        new(CircularBuffer{UInt8}(capacity), Vector{UInt8}(undef, 32))
    end
    function Base.peek(io::DataStreamIO, t::Type)
        first = io.buf.first
        length = io.buf.length
        v = read(io, t)
        io.buf.first = first
        io.buf.length = length
        v
    end
    Base.skip(io::DataStreamIO, n::Integer) = for i in 1:n popfirst!(io.buf) end
    Base.bytesavailable(io::DataStreamIO) = length(io.buf)
    Base.close(io::DataStreamIO) = resize!(io.ref, 0)
    Base.isopen(io::DataStreamIO) = length(io.ref) != 0
    Base.eof(io::DataStreamIO) = bytesavailable(io) == 0
    Base.write(io::DataStreamIO, x::UInt8) = (push!(io.buf, x); 1)
    Base.read(io::DataStreamIO, ::Type{UInt8}) = popfirst!(io.buf)
end

writespaceavailable(io::DataStreamIO) = capacity(io.buf) - length(io.buf)
"Read at most n bytes from an IO"
function Base.write(to::IO, from::IO, n::Integer)
    written = 0
	remaining = n
    while bytesavailable(from) > 0 && remaining > 0
		k = write(to, read(from, UInt8))
        written += k
		remaining -= k 
    end
    written 
end

"Read at most n bytes from an IO"
Base.read(from::IO, to::IO, n::Integer) = write(to, from, n)

function skipuntil(f, io::IO; skipsize=1, ensuresize=1, block=false)
    valid = false
    while bytesavailable(io) >= ensuresize || block
        while !(valid=f(io))
            skip(io, skipsize) 
        end
    end
    valid
end
