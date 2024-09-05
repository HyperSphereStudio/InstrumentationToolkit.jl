module Communication

using LibSerialPort, Observables, DataStructures

export MicroControllerPort, setport, readport, RegexReader, DelimitedReader, PortsObservable, FixedLengthReader, SimpleConnection, send
export readn, peekn, readl, peekl, update
export PortsDropDown

include("SimpleConnection.jl")

mutable struct MicroControllerPort <: IO
    name
    sp
    baud::Integer
    mode::SPMode
    ndatabits::Integer
    parity::SPParity
    nstopbits::Integer
    connection::Observable{Bool}

    function MicroControllerPort(name, baud; mode=SP_MODE_READ_WRITE, ndatabits=8, parity=SP_PARITY_NONE, nstopbits=1)
        return new(name, nothing, baud, mode, ndatabits, parity, nstopbits, Observable(false; ignore_equal_values=true))
    end
        
    Observables.on(cb::Function, p::MicroControllerPort; update=false) = on(cb, p.connection; update=update)
    Base.setindex!(p::MicroControllerPort, port) = setport(p, port)
	
	Base.bytesavailable(p::MicroControllerPort) = bytesavailable(p.sp)
	Base.read(p::MicroControllerPort, ::Type{UInt8}) = read(p.sp, UInt8)
	Base.read(p::MicroControllerPort) = read(p.sp)
	Base.write(p::MicroControllerPort, v::UInt8) = write(p.sp, v)
	Base.write(p::MicroControllerPort, a::AbstractArray{UInt8}) = write(p, pointer(a), length(a))
	Base.write(p::MicroControllerPort, ptr::Ptr{T}, n::Integer) where T = write(p, convert(Ptr{UInt8}, ptr), n * sizeof(T))
	Base.close(p::MicroControllerPort) = isopen(p) && (close(p.sp); p.sp=nothing; p.connection[] = false)
	Base.isopen(p::MicroControllerPort) = p.sp !== nothing && isopen(p.sp)
	Base.eof(p::MicroControllerPort) = !isopen(p)
	Base.print(io::IO, p::MicroControllerPort) = print(io, "Port[$(p.name), baud=$(p.baud), open=$(isopen(p))]")

	function Base.write(p::MicroControllerPort, ptr::Ptr{UInt8}, n::Integer)
		isopen(p) || error("Port not Opened!")
		LibSerialPort.sp_nonblocking_write(s.port.sp.ref, ptr, n)
	end
end

function setport(p::MicroControllerPort, name)
    close(p)
    (name == "" || name === nothing) && return false
    p.sp = LibSerialPort.open(name, p.baud; mode=p.mode, ndatabits=p.ndatabits, parity=p.parity, nstopbits=p.nstopbits)
    p.connection[] = true
    return true
end

struct RegexStreamReader
	src::IO
	onPacket::Function
    rgx::Regex 
	buf::CircularBuffer{UInt8}
	
	RegexStreamReader(src, onPacket, rgx, buffer_size) = new(src, onPacket, rgx, CircularBuffer{UInt8}(buffer_size))
	Base.eof(rsr::RegexStreamReader) = eof(rsr.src)
end

function update(rsr::RegexStreamReader)
	append!(rsr.buf, read(rsr.src))
	str = String(@view rsr.buf[1:end])
	m = match(rsr.rgx, s)
	if m !== nothing
		n = length(m.match)
		rsr.onPacket(Base.unsafe_wrap(Array, pointer(m.match), n))
		
		for i in 1:(m.offset + n - 1)		#Trim past match		
			pop!(rsr.buf)		
		end
	end
end 

DelimitedReader(src::IO, onPacket::Function, delimeter = "[\n\r]", buffer_size=256) = RegexStreamReader(src, onPacket, Regex("(.*)(?:$delimeter)"), buffer_size)

struct FixedLengthReader
	src::IO
	onPacket::Function
	length::Integer 
	
	Base.eof(flr::FixedLengthReader) = eof(flr.src)
end
function update(r::FixedLengthReader)
	bytesavailable(r.src) >= r.length && r.onPacket(read(r.src, r.length))
end

function async_read_update(reader; sleep_delta=1E-2)
	alive = Ref(true)
	@async begin
		while alive[] && !eof(reader)
			update(reader)
			sleep(sleep_delta)
		end
	end
	alive
end

mutable struct SimpleConnection <: IO
	src::IO
    scp::SimpleConnectionProtocol

    function SimpleConnection(src::IO, on_packet_rx::Function, max_payload_size::Integer=256)
        new(src, SimpleConnectionProtocol(on_packet_rx, max_payload_size))
    end

	Base.eof(c::SimpleConnection) = eof(c.src)
    Base.close(c::SimpleConnection) = close(c.port)
    Base.isopen(c::SimpleConnection) = isopen(c.port)
    Base.print(io::IO, c::SimpleConnection) = print(io, "Connection[Name=$(c.port.name), Open=$(isopen(c))]")
    Observables.on(cb::Function, p::SimpleConnection; update=false) = on(cb, p.port; update=update)
    Base.setindex!(p::SimpleConnection, port) = setport(p, port)
	Base.write(s::SimpleConnection, v::UInt8) = write(s.scp, v)
	Base.write(s::SimpleConnection, v::AbstractArray{UInt8}, n=length(v)) = write(s.scp, v, n)
end
update(r::SimpleConnection) = read(r.scp, read(r.src))
setport(s::SimpleConnection, name) = setport(s.port, name)
send(s::SimpleConnection, args...) = (foreach(a->write(s, a), args); write(s.port, take!(s.scp)))

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