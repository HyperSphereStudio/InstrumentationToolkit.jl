module Communication

using LibSerialPort, Observables

export MicroControllerPort, setport, readport, RegexReader, DelimitedReader, PortsObservable, FixedLengthReader, SimpleConnection, send
export readn, peekn, readl, peekl
export PortsDropDown

include("SimpleConnection.jl")

abstract type IOReader end

Base.take!(::IOReader, data::IOBuffer) = ()

mutable struct MicroControllerPort{R}
    name
    sp
    baud::Integer
    mode::SPMode
    ndatabits::Integer
    parity::SPParity
    nstopbits::Integer
    buffer::IOBuffer
    reader::R
    connection::Observable{Bool}

    function MicroControllerPort(name, baud, reader; mode=SP_MODE_READ_WRITE, ndatabits=8, parity=SP_PARITY_NONE, nstopbits=1)
        return new{typeof(reader)}(name, nothing, baud, mode, ndatabits, parity, nstopbits, IOBuffer(), reader, Observable(false; ignore_equal_values=true))
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
        return false
    end
    LibSerialPort.bytesavailable(p.sp) > 0 || return true
   
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

    return true
end

function Base.write(p::MicroControllerPort, ptr::Ptr{UInt8}, n::Integer)
	isopen(p) || error("Port not Opened!")
    LibSerialPort.sp_nonblocking_write(s.port.sp.ref, ptr, n)
end

Base.write(p::MicroControllerPort, ptr::Ptr{T}, n::Integer) where T = write(p, convert(Ptr{UInt8}, ptr), n * sizeof(T))
Base.write(p::MicroControllerPort, a::AbstractArray{UInt8}) = write(p, pointer(a), length(a))
Base.write(p::MicroControllerPort, io::IOBuffer) = write(p, pointer(io.data), io.ptr - 1)

struct FixedLengthReader <: IOReader length::Integer end
function Base.take!(r::FixedLengthReader, io::IOBuffer)
    if bytesavailable(io) >= r.length
        data = Array{UInt8}(undef, r.length)
        readbytes!(io, data, r.length)
        return data
    end
    return nothing
end

mutable struct SimpleConnection <: IOReader
    port::MicroControllerPort
    scp::SimpleConnectionProtocol
    buffer::Vector{UInt8}

    function SimpleConnection(port::MicroControllerPort, on_packet_rx::Function, max_payload_size::Integer=256)
        c = new(port, SimpleConnectionProtocol(on_packet_rx, max_payload_size), zeros(UInt8, 64))
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
send(s::SimpleConnection, args...) = (foreach(a->write(s, a), args); write(s.port, take!(s.scp)))
Base.write(s::SimpleConnection, v::UInt8) = write(s.scp, v)
Base.write(s::SimpleConnection, v::AbstractArray{UInt8}, n=length(v)) = write(s.scp, v, n)
function Base.take!(r::SimpleConnection, io::IOBuffer)
    while bytesavailable(io) > 0
        n = readbytes!(io, r.buffer)
        readbytes!(r.scp, buffer, n)
    end
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

const PortsObservable = Observable(Set{String}())

function __init__()
    global __portlistener__
    __portlistener__ = Timer(0; interval=2) do t
        nl = Set(get_port_list())
        issetequal(PortsObservable[], nl) && return
        PortsObservable[] = nl
    end
end

function PortsDropDown(on_port_select)
    ids = DropDownItemID[]
    dd = DropDown()
    observable_func = Ref{Any}(nothing)
    
    connect_signal_realize!(dd) do self
        initial = true
        observable_func[] = on(PortsObservable; update=true) do pl                                
                                foreach(id -> remove!(dd, id), ids)
                                empty!(ids)
                                for id in pl
                                   push!(ids, push_back!(_->(initial || on_port_select(id); nothing), dd, id))                                     
                                end
                                initial = false
                            end
        nothing
    end

    connect_signal_unrealize!(dd) do self
        off(observable_func[])
        nothing
    end

    dd
end

end