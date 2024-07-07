using Pkg

Pkg.activate(".")

println("Reinstall [y\n]?:")

readline() == "y" && begin
	include("Install.jl")
end

println("Precompiling...")
Pkg.precompile()
