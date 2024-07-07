module Communication

using LibSerialPort, PrecompileTools, Observables

export MicroControllerPort, setport, readport, RegexReader, DelimitedReader, PortsObservable, FixedLengthReader, SimpleConnection, send
export readn, peekn, readl, peekl

abstract type IOReader end

Base.take!(::IOReader, data::IOBuffer) = ()

mutable struct MicroControllerPort
    name
    sp
    baud::Integer
    mode::SPMode
    ndatabits::Integer
    parity::SPParity
    nstopbits::Integer
    buffer::IOBuffer
    reader
    connection::Observable{Bool}

    function MicroControllerPort(name, baud, reader; mode=SP_MODE_READ_WRITE, ndatabits=8, parity=SP_PARITY_NONE, nstopbits=1)
        return new(name, nothing, baud, mode, ndatabits, parity, nstopbits, IOBuffer(), reader, Observable(false; ignore_equal_values=true))
    end
        
    Observables.on(cb::Function, p::MicroControllerPort; update=false) = on(cb, p.connection; update=update)
    Base.setindex!(p::MicroControllerPort, port) = setport(p, port)
end

struct RegexReader <: IOReader
    rgx::Regex 
    length_range::AbstractRange
end
DelimitedReader(delimeter = "[\n\r]", length_range = 1:1000) = RegexReader(Regex("(.*)(?:$delimeter)"), length_range)
function Base.take!(regex::RegexReader, io::IOBuffer)
    s = read(io, String)
    m = match(regex.rgx, s)
    if m !== nothing
        str = m[1]                                                   #Match with the payload
        io.ptr = length(m.match) + 1
        return length(str) in regex.length_range ? str : nothing     #Set Range Limit
    end
    io.ptr = 1
    return nothing
end

Base.close(p::MicroControllerPort) = isopen(p) && (LibSerialPort.close(p.sp); p.sp=nothing; p.connection[] = false)
Base.isopen(p::MicroControllerPort) = p.sp !== nothing && LibSerialPort.isopen(p.sp)
Base.write(p::MicroControllerPort, v::UInt8) = write(p.sp, v)
Base.print(io::IO, p::MicroControllerPort) = print(io, "Port[$(p.name), baud=$(p.baud), open=$(isopen(p))]")
function setport(p::MicroControllerPort, name)
    close(p)
    (name == "" || name === nothing) && return false
    p.sp = LibSerialPort.open(name, p.baud; mode=p.mode, ndatabits=p.ndatabits, parity=p.parity, nstopbits=p.nstopbits)
    p.connection[] = true
    return true
end

function readport(f::Function, p::MicroControllerPort)
    if !isopen(p)
        close(p)
        return
    end
    LibSerialPort.bytesavailable(p.sp) > 0 || return
   
    try
        p.buffer.ptr = p.buffer.size + 1
        write(p.buffer, nonblocking_read(p.sp))
    catch e
        showerror(e)
        close(p)
    end
    
    while p.buffer.size > 0
        p.buffer.ptr = 1
        mark(p.buffer)
        read_data = take!(p.reader, p.buffer)
        read_data === nothing || f(read_data)
        bytes_read = p.buffer.ptr - 1
        bytes_read > 0 && deleteat!(p.buffer.data, 1:bytes_read)
        p.buffer.size -= bytes_read
        read_data === nothing && break
    end
end

struct FixedLengthReader <: IOReader length::Integer end
function Base.take!(r::FixedLengthReader, io::IOBuffer)
    if bytesavailable(io) >= r.length
        data = Array{UInt8}(undef, r.length)
        readbytes!(io, data, r.length)
        return data
    end
    return nothing
end


const MAGIC_NUMBER::UInt32 = 0xDEADBEEF
const TAIL_MAGIC_NUMBER::UInt8 = 0xEE

mutable struct SimpleConnection <: IOReader
    port::MicroControllerPort
    write_buffer::IOBuffer

    function SimpleConnection(port::MicroControllerPort)
        c = new(port, IOBuffer())
        port.reader = c
        c
    end

    Base.close(c::SimpleConnection) = close(c.port)
    Base.isopen(c::SimpleConnection) = isopen(c.port)
    Base.print(io::IO, c::SimpleConnection) = print(io, "Connection[Name=$(c.port.name), Open=$(isopen(c))]")
    Observables.on(cb::Function, p::SimpleConnection; update=false) = on(cb, p.port; update=update)
    Base.setindex!(p::SimpleConnection, port) = setport(p, port)
end
setport(s::SimpleConnection, name) = setport(s.port, name)
readport(f::Function, s::SimpleConnection) = readport(f, s.port)

function send(s::SimpleConnection, args...)
    s.write_buffer.ptr = 1
    s.write_buffer.size = 0
    writestd(x::T) where T <: Number = write(s.write_buffer, hton(x)) 
    writestd(x) = write(s.write_buffer, x) 
    writestd(MAGIC_NUMBER)
    writestd(UInt8(sum(sizeof, args)))
    foreach(writestd, args)
    writestd(TAIL_MAGIC_NUMBER)
    LibSerialPort.sp_nonblocking_write(s.port.sp.ref, pointer(s.write_buffer.data), s.write_buffer.ptr - 1)
end

readn(io::IO, ::Type{T}) where T <: Number = ntoh(read(io, T))
peekn(io::IO, ::Type{T}) where T <: Number = ntoh(peek(io, T))
peekn(io::IO, T::Type) = peek(io, T)
readn(io::IO, T::Type) = read(io, T)
readn(io::IO, Types::Type...) = [readn(io, T) for T in Types]
readn(io::IO, T::Type, count::Integer) = [readn(io, T) for i in 1:count]

readl(io::IO, ::Type{T}) where T <: Number = ltoh(read(io, T))
peekl(io::IO, ::Type{T}) where T <: Number = ltoh(peek(io, T))
peekl(io::IO, T::Type) = peek(io, T)
readl(io::IO, T::Type) = read(io, T)
readl(io::IO, Types::Type...) = [readl(io, T) for T in Types]
readl(io::IO, T::Type, count::Integer) = [readl(io, T) for i in 1:count]

function Base.take!(r::SimpleConnection, io::IOBuffer)
    head::UInt32 = 0
    canread(s::Integer) = bytesavailable(io) >= s
    canread(::Type{T}) where T = canread(sizeof(T))
    canread(x) = canread(sizeof(typeof(x)))

    while canread(UInt32) && (head = peekn(io, UInt32)) != MAGIC_NUMBER
        io.ptr += 1                             
    end

    mark(io)                                                      #Mark after discardable data
    
    if canread(sizeof(MAGIC_NUMBER) + 1) && (readn(io, UInt32) == MAGIC_NUMBER)
        size = read(io, UInt8)
        if canread(size + 1)
            base_pos = io.ptr
            io.ptr += size
            if read(io, UInt8) == TAIL_MAGIC_NUMBER               #Peek ahead to make sure tail is okay
                return IOBuffer(@view(io.data[base_pos:(base_pos + size - 1)]))
            else
                return nothing
            end
        end
    end

    io.ptr = io.mark
    return nothing
end


const PortsObservable = Observable(Set{String}())

function __init__()
    global __portlistener__
    __portlistener__ = Timer(0; interval=2) do t
        nl = Set(get_port_list())
        issetequal(PortsObservable[], nl) && return
        PortsObservable[] = nl
    end
end

#=
    @setup_workload begin
        @compile_workload begin
            using GLMakie, Observables, CSV, DataFrames, LibSerialPort, HTTP, FileIO, PrecompileTools
	    test_port()
        end
    end
=#

end