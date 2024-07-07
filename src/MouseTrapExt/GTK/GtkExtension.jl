include("GtkObservables.jl")

Base.getindex(g::GtkEntry, ::Type{String}) = g.text
Base.getindex(g::GtkLabel, ::Type{String}) = g.label
Base.getindex(g::Union{GtkEntry, GtkLabel}, t::Type = String) = parse(t, g[String])
Base.setindex!(g::GtkLabel, v) = g.label = string(v)
Base.setindex!(g::GtkEntry, v) = g.text = string(v)

Base.getindex(g::GtkComboBoxText, ::Type{String} = String) = Gtk4.active_text(g)
Base.getindex(g::GtkComboBoxText, ::Type{T}) where T <: Integer = g.active
Base.setindex!(g::GtkComboBoxText, v::Integer) = g.active = v
Base.setindex!(g::GtkComboBoxText, v::String) = Gtk4.active_text(g, v)

Base.getindex(g::Union{GtkScale, GtkAdjustment}, ::Type{T} = Number) where T <: Number = Gtk4.value(g)
Base.setindex!(g::Union{GtkScale, GtkAdjustment}, v) = Gtk4.value(g, v)

Base.getindex(g::GtkCheckButton, ::Type{Bool}) = Gtk4.value(g)
Base.setindex(g::GtkCheckButton, v) = Gtk4.value(g, v)
Base.append!(b::GtkWidget, items) = foreach(x -> push!(b, x), items)
Base.append!(b::GtkWidget, items...) = foreach(x -> push!(b, x), items)
signal_block(f, g, handler_id) = (signal_handler_block(g, handler_id); f(g); signal_handler_unblock(g, handler_id))

function gtk_init()
    ENV["GTK_THEME"] = "Adwaita:dark"
end