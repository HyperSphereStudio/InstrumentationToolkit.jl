module GUI

using Reexport

@reexport using Mousetrap

include("MiniGtk/minigtk.jl")
include("Observables.jl")
include("theme_hypersphere.jl")

function Box(orientation::Symbol)
    if orientation == :v
        Box(ORIENTATION_VERTICAL)
    elseif orientation == :h
        Box(ORIENTATION_HORIZONTAL)
    else
        error("Unknown orientation $orientation")
    end
end

(f::Action)() = activate!(f)

end