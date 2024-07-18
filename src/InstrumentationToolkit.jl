module InstrumentationToolkit
	using FileIO, PrecompileTools, DataFrames
	
	export dict, Expando, GUI, HTimer, resume, pause, start

    include("MouseTrapExt/Mousetrap.jl")
    include("Communication/Communication.jl")
    include("Math/Math.jl")
	
	Base.isopen(::Nothing) = false
    Base.append!(d::Dict, items::Pair...) = foreach(p -> d[p[1]] = p[2], items)
	dict(; values...) = Dict(values...)

	struct Expando{T}
		dict::Dict{Symbol, T}

		Expando{T}(; args...) where T = new{T}(Dict{Symbol, T}(collect(args)))
		Expando() = Expando{Any}()

		Base.getproperty(x::Expando, s::Symbol) = getfield(x, :dict)[s]
		Base.setproperty!(x::Expando, s::Symbol, v) = getfield(x, :dict)[s] = v
		Base.delete!(x::Expando, s) = delete!(Dict(x), s)
		Base.keys(x::Expando) = keys(Dict(x))
		Base.values(x::Expando) = values(Dict(x))
		Base.Dict(x::Expando) = x.dict
	end 
	
	mutable struct HTimer
        t::Union{Nothing, Timer}
        cb::Function
        delay::Real
        interval::Real
    
        HTimer(cb::Function, delay, interval = 0; start=true) = (t = new(nothing, cb, delay, interval); start && resume(t); return t)
        Base.close(h::HTimer) = h.t !== nothing && (close(h.t); h.t = nothing)
    end
    resume(h::HTimer) = h.t === nothing && (h.t = Timer(h.cb, h.delay; interval=h.interval))
    pause(h::HTimer) = close(h)
	start(h::HTimer) = resume(h)
    Base.reset(h::HTimer) = (pause(h); resume(h))

	using Pkg
	function install_graphics()
		try 
			@eval using libmousetrap_jll
		catch
			println("Installing Graphics Libraries") 
			Pkg.add(url="https://github.com/HyperSphereStudio/libmousetrap_jll.jl")
			Pkg.add(url="https://github.com/HyperSphereStudio/Mousetrap.jl")
			Pkg.add(url="https://github.com/HyperSphereStudio/MousetrapMakie.jl")
		end
	end
end