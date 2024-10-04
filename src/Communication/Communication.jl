module Communication

using LibSerialPort, Observables, DataStructures, Mousetrap

export RegexReader, DelimitedReader, PortsObservable, FixedLengthReader, SimpleConnection, send
export readn, peekn, readl, peekl, update, async_update_loop
export PortsDropDown

include("SimpleConnection.jl")

struct ReadBuffer
	io::IOBuffer
	buf::Vector{UInt8}
	ReadBuffer() = new(IOBuffer(; read=true, write=false, append=false), zeros(UInt8, 64))
	function Base.setindex!(rb::ReadBuffer, v::Vector{UInt8})
		rb.io.data = v
		rb.io.ptr = 1
		rb.io.size = length(v)
	end
end
Base.reset(rb::ReadBuffer) = (rb.io.size=0; rb.io.ptr=1)
function Base.write(rb::ReadBuffer, k::IO, max_bytes=10000)
	bytes_rem = max_bytes
	while bytesavailable(k) > 0 && bytes_rem > 0
		n = readbytes!(k, rb.buf, min(bytesavailable(k), length(rb.buf)))
		write(rb.io, @view rb.buf[1:n])
		bytes_rem -= n
	end
end

struct RegexStreamReader
	src::IO
	onPacket::Function
    rgx::Regex 
	buf::CircularBuffer{UInt8}
	io::ReadBuffer
	
	RegexStreamReader(src, onPacket, rgx, buffer_size) = new(src, onPacket, rgx, CircularBuffer{UInt8}(buffer_size), ReadBuffer())
	Base.eof(rsr::RegexStreamReader) = eof(rsr.src)
end

function update(rsr::RegexStreamReader)
	append!(rsr.buf, read(rsr.src))
	str = String(@view rsr.buf[1:end])
	m = match(rsr.rgx, s)
	if m !== nothing
		n = length(m.match)
		
		reset(rsr.io)
		write(rsr.io.io, m.match, n)		#Write from match to iobuf
		rsr.onPacket(rsr.io.io)
		
		for i in 1:(m.offset + n - 1)		#Trim past match		
			pop!(rsr.buf)		
		end
	end
end 

DelimitedReader(src::IO, onPacket::Function, delimeter = "[\n\r]", buffer_size=256) = RegexStreamReader(src, onPacket, Regex("(.*)(?:$delimeter)"), buffer_size)

struct FixedLengthReader
	src::IO
	onPacket::Function
	length::Int
	bp::ReadBuffer	
	
	FixedLengthReader(src::IO, onPacket::Function, length::Integer) = new(src, onPacket, length, ReadBuffer())
	
	Base.eof(flr::FixedLengthReader) = eof(flr.src)
end
function update(r::FixedLengthReader)
	if bytesavailable(r.src) >= r.length
		reset(r.bp)
		write(r.bp, r.src, r.length)
		r.onPacket(r.bp.io)
	end
end

function async_update_loop(reader; sleep_delta=1E-2)
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
		rb = ReadBuffer()
        new(src, SimpleConnectionProtocol(
			function packet_rx_to_io(packet::AbstractArray{UInt8})
				rb[] = packet
				on_packet_rx(rb.io)
			end, max_payload_size))
    end

	Base.eof(c::SimpleConnection) = eof(c.src)
    Base.print(io::IO, c::SimpleConnection) = print(io, "Connection[Name=$(c.port.name), Open=$(isopen(c))]")
    Observables.on(cb::Function, p::SimpleConnection; update=false) = on(cb, p.port; update=update)
	
	Base.write(s::SimpleConnection, v::UInt8) = write(s.scp, v)
	Base.unsafe_write(s::SimpleConnection, p::Ptr{UInt8}, n::UInt) = unsafe_write(s.scp, p, n)
end
Base.open(r::SimpleConnection, src::IO) = r.src = src
update(r::SimpleConnection) = isopen(r) && read(r.scp, read(r.src))
send(s::SimpleConnection, args...) = (foreach(a->write(s, a), args); flush(s))
error_count(c::SimpleConnection) = Int(error_count(c.scp))
Base.isopen(c::SimpleConnection) = isopen(c.src) && !eof(c.src)
Base.bytesavailable(c::SimpleConnection) = bytesavailable(c.src)
Base.flush(s::SimpleConnection) = write(s.src, take!(s.scp))

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

function safe_wrap(f; on_error=(e->showerror(stdout, e, catch_backtrace())))
    function safe_wrapping(args...)
        try 
            f(args...)
        catch e
            on_error(e)
        end
    end
end

function PortsDropDown(on_port_select)
    dd = DropDown()
    observable_func = Ref{Any}(nothing)
    push_back!(_->(on_port_select(""); nothing), dd, "(None)")

    connect_signal_realize!(dd) do self
        observable_func[] = on(PortsObservable; update=true) do pl       
                                empty!(dd)      #Wont Remove First Item
                                for id in pl
                                    push_back!(_->(on_port_select(id); nothing), dd, id)                                   
                                end                     
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