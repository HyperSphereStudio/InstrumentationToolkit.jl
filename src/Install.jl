using Pkg

Pkg.activate("InstrToolkitEnv", shared=true)

println("Install Useful Libraries to Env [Y/N]?")

if uppercase(read(stdin, Char)) == 'Y'
	println("Adding Useful Libraries....")
	try Pkg.rm(["mousetrap", "mousetrap_windows_jll", "mousetrap_linux_jll", "mousetrap_apple_jll", "libmousetrap_jll", "MousetrapMakie"]) catch e println(e) end

	mousetrap_pkgs = [Pkg.PackageSpec(url="https://github.com/clemapfel/mousetrap.jl"), 
					  Pkg.PackageSpec(url="https://github.com/clemapfel/mousetrap_jll")]

	light_pkgs = Pkg.PackageSpec.(["StaticArrays", "LsqFit", "Distributions", "DualNumbers", "Observables",
	 "LibSerialPort", "HTTP", "FileIO", "Unitful", "CSV", "DSP", "HCubature",
	 "Glib_jll"])
	 
	large_pkgs = Pkg.PackageSpec.(["DataFrames", "GLMakie", "ForwardDiff", "Optim", "GeometryBasics", "DifferentialEquations", "Flux", "CUDA", "ModelToolkit"])
	
	pkgs = [mousetrap_pkgs..., light_pkgs..., large_pkgs...]
	
	Pkg.add(pkgs)
end

#Pkg.add(url="https://github.com/HyperSphereStudio/JuliaSAILGUI.jl")