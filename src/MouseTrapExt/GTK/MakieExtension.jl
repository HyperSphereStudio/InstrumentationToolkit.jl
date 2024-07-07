using ShaderAbstractions, ModernGL
using GLMakie.GLAbstraction
using GLMakie.Makie
using GLMakie.Makie: MouseButtonEvent, KeyEvent

include("theme_hypersphere.jl")

function Base.empty!(ax::Axis3)
    while !isempty(ax.scene.plots)
        delete!(ax.scene, ax.scene.plots[end])
    end
end