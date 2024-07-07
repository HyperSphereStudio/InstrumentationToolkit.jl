module InstrumentationToolkit
	using FileIO, PrecompileTools, DataFrames
	
	export dict, Expando, GUI

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