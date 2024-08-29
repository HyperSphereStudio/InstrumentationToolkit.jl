using Libdl

export SimpleConnectionProtocol, payload, error_count

if Sys.iswindows()
    const SimpleConnectionLib = dlopen("SimpleConnection/libConnectionProtocol.dll")
else
    @info "Incompatible operating system for simple connection protocol!"
end

if @isdefined SimpleConnectionLib
const SimpleConnectionProtocol_payloadOffset = ccall(dlsym(SimpleConnectionLib, :SimpleConnectionProtocol_payloadOffset), UInt16, ()) + 1
const SimpleConnectionProtocol_new_f = dlsym(SimpleConnectionLib, :SimpleConnectionProtocol_new)
const SimpleConnectionProtocol_free_f = dlsym(SimpleConnectionLib, :SimpleConnectionProtocol_free)
const SimpleConnectionProtocol_encodePacket_f = dlsym(SimpleConnectionLib, :SimpleConnectionProtocol_encodePacket)
const SimpleConnectionProtocol_recieve_f = dlsym(SimpleConnectionLib, :SimpleConnectionProtocol_recieve)
const SimpleConnectionProtocol_recieveChar_f = dlsym(SimpleConnectionLib, :SimpleConnectionProtocol_recieveChar)
const SimpleConnectionProtocol_errorCount_f = dlsym(SimpleConnectionLib, :SimpleConnectionProtocol_errorCount)
const SimpleConnectionProtocol_minBufferSize_f = dlsym(SimpleConnectionLib, :SimpleConnectionProtocol_minBufferSize)
end

mutable struct SimpleConnectionProtocol
    handle::Ptr{Cvoid}
    rx_buffer::Vector{UInt8}        #Handle
    tx_buffer::Vector{UInt8}        #Handle
    packet_index::Int
    on_packet_rx::Base.CFunction

    function SimpleConnectionProtocol(on_packet_rx::Function, max_payload_size::Integer=256)
        cap = @ccall $SimpleConnectionProtocol_minBufferSize_f(max_payload_size::UInt16)::UInt16
        SimpleConnectionProtocol(zeros(UInt8, cap), zeros(UInt8, cap), on_packet_rx)
    end

    function SimpleConnectionProtocol(rx_buffer::Vector{UInt8}, tx_buffer::Vector{UInt8}, on_packet_rx_f::Function)
        length(rx_buffer) >= length(tx_buffer) || error("Rx Buffer Tx Buffer Length Mismatch")
        handle = @ccall $SimpleConnectionProtocol_new_f(rx_buffer::Ptr{UInt8}, tx_buffer::Ptr{UInt8}, length(rx_buffer)::UInt16)::Ptr{Cvoid}
        
        on_packet_rx = @cfunction $(
            (p, n, d) -> on_packet_rx_f(unsafe_wrap(Array, p+1, n))
        ) Cvoid (Ptr{UInt8}, Cint, Ptr{Cvoid})

        x = new(handle, rx_buffer, tx_buffer, 0, on_packet_rx)
        reset(x)
        finalizer(x) do x
            @ccall $SimpleConnectionProtocol_free_f(x.handle::Ptr{Cvoid})::Nothing
        end
        x
    end
end

payloadsize(scp::SimpleConnectionProtocol) = scp.packet_index - SimpleConnectionProtocol_payloadOffset
payload(scp::SimpleConnectionProtocol) = @view scp.tx_buffer[SimpleConnectionProtocol_payloadOffset:end]
Base.reset(scp::SimpleConnectionProtocol) = scp.packet_index = SimpleConnectionProtocol_payloadOffset
function Base.write(scp::SimpleConnectionProtocol, v::AbstractArray{UInt8}, n=length(v))
    scp.tx_buffer[(scp.packet_index + 1):(scp.packet_index + n + 1)] = v[:]
    scp.packet_index += n
    n
end
function Base.write(scp::SimpleConnectionProtocol, v::UInt8)
    scp.packet_index += 1
    scp.tx_buffer[scp.packet_index] = v
    1
end
function Base.take!(scp::SimpleConnectionProtocol)
    packet_size = @ccall $SimpleConnectionProtocol_encodePacket_f(scp.handle::Ptr{Cvoid}, payloadsize(scp)::UInt16)::UInt16
    reset(scp)
    @view scp.tx_buffer[1:packet_size]
end
error_count(scp::SimpleConnectionProtocol) = @ccall $SimpleConnectionProtocol_errorCount_f(scp.handle::Ptr{Cvoid})::UInt32

function Base.read(scp::SimpleConnectionProtocol, v::UInt8)
    @ccall $SimpleConnectionProtocol_recieveChar_f(scp.handle::Ptr{Cvoid}, v::UInt8, scp.on_packet_rx::Ptr{Cvoid}, C_NULL::Ptr{Cvoid})::UInt16
end

function Base.readbytes!(scp::SimpleConnectionProtocol, v::AbstractVector{UInt8}, nb=length(v))
    @ccall $SimpleConnectionProtocol_recieve_f(scp.handle::Ptr{Cvoid}, v::Ptr{UInt8}, nb::UInt16, scp.on_packet_rx::Ptr{Cvoid}, C_NULL::Ptr{Cvoid})::UInt16
end