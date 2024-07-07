module GUI

export MousetrapGLMakieWindow, remove_row!

using Reexport

@reexport using Mousetrap

include("MiniGtk/minigtk.jl")
include("Observables.jl")
include("theme_hypersphere.jl")

function Base.setindex!(grid::Grid, child, i, j)
    insert_at!(grid, child, first(i)-1, first(j)-1, length(i), length(j))
end

function MousetrapGLMakieWindow(fig) 
    canvas = GLMakieArea()
    
    connect_signal_realize!(canvas) do self
        screen = create_glmakie_screen(canvas)
        display(screen, fig)
        
        return nothing
    end

    fig, canvas
end

function remove_row!(cv::ColumnView, row)
    smm = get_selection_model(cv)
    model = Mousetrap.detail.get_internal(smm._internal)
    sm = get_selection_mode(smm)

    list_store = if sm == SELECTION_MODE_NONE
        ccall((:gtk_none_selection_get_model, Mousetrap.detail.GTK4_jll.libgtk4), Ptr{Cvoid}, (Ptr{Cvoid}, ), model)
    elseif sm == SELECTION_MODE_SINGLE
        ccall((:gtk_single_selection_get_model, Mousetrap.detail.detail.GTK4_jll.libgtk4), Ptr{Cvoid}, (Ptr{Cvoid}, ), model)
    else
        ccall((:gtk_multiple_selection_get_model, Mousetrap.detail.detail.GTK4_jll.libgtk4), Ptr{Cvoid}, (Ptr{Cvoid}, ), model)
    end    

    ccall((:g_list_store_remove, Mousetrap.detail.Glib_jll.libgio), Cvoid, (Ptr{Cvoid}, Cuint), list_store, Mousetrap.from_julia_index(row))
end

end