using Libdl, libsimplecommunicationencoder_jll

export SimpleConnectionProtocol, payload, error_count

const libprotocolpath = libsimplecommunicationencoder_jll.libsimplecommunicationencoder

mutable struct SimpleConnectionProtocol <: IO
    handle::Ptr{Cvoid}
    on_packet_rx::Base.CFunction

    function SimpleConnectionProtocol(on_packet_rx_f::Function, max_payload_size::Integer)
        handle = @ccall libprotocolpath.SimpleConnectionProtocol_new(max_payload_size::UInt16)::Ptr{Cvoid}
        
        on_packet_rx = @cfunction $(
            (p, n, d) -> on_packet_rx_f(unsafe_wrap(Array, p, n))
        ) Cvoid (Ptr{UInt8}, Cint, Ptr{Cvoid})

        x = new(handle, on_packet_rx)
        
        finalizer(x) do x
            @ccall libprotocolpath.SimpleConnectionProtocol_free(x.handle::Ptr{Cvoid})::Nothing
        end
        x
    end
end
function Base.write(scp::SimpleConnectionProtocol, v::AbstractArray{UInt8}, n=length(v))
    @ccall libprotocolpath.SimpleConnectionProtocol_write(scp.handle::Ptr{Cvoid}, pointer(v)::Ptr{UInt8}, length(v)::UInt16)::UInt16
end
function Base.write(scp::SimpleConnectionProtocol, v::UInt8)
    @ccall libprotocolpath.SimpleConnectionProtocol_writeChar(scp.handle::Ptr{Cvoid}, v::UInt8)::UInt16
end
function Base.take!(scp::SimpleConnectionProtocol)
    packet = @ccall libprotocolpath.SimpleConnectionProtocol_getTxPacket(scp.handle::Ptr{Cvoid})::Ptr{UInt8}
    packetLen = @ccall libprotocolpath.SimpleConnectionProtocol_encodeTxPacket(scp.handle::Ptr{Cvoid})::UInt16
    unsafe_wrap(Array, packet, packetLen)
end
error_count(scp::SimpleConnectionProtocol) = @ccall libprotocolpath.SimpleConnectionProtocol_errorCount(scp.handle::Ptr{Cvoid})::UInt32

function Base.read(scp::SimpleConnectionProtocol, v::UInt8)
    @ccall libprotocolpath.SimpleConnectionProtocol_recieveChar(scp.handle::Ptr{Cvoid}, v::UInt8, scp.on_packet_rx::Ptr{Cvoid}, C_NULL::Ptr{Cvoid})::UInt16
end

Base.read(scp::SimpleConnectionProtocol, k::AbstractVector{UInt8}) = readbytes!(scp, k)

function Base.readbytes!(scp::SimpleConnectionProtocol, v::AbstractVector{UInt8}, nb=length(v))
    @ccall libprotocolpath.SimpleConnectionProtocol_recieve(scp.handle::Ptr{Cvoid}, v::Ptr{UInt8}, nb::UInt16, scp.on_packet_rx::Ptr{Cvoid}, C_NULL::Ptr{Cvoid})::UInt16
end
