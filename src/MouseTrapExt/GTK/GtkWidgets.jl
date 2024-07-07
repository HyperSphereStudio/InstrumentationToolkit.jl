export makewidgetwithtitle, buttonwithimage, makewidgetswithtitle

on_update_signal_name(::GtkButton) = "clicked"
on_update_signal_name(::GtkComboBoxText) = "changed"
on_update_signal_name(::Union{GtkScale, GtkAdjustment}) = "value-changed"
on_update_signal_name(::GtkEntry) = "activate"
on_update_signal_name(::GtkCheckButton) = "toggled"

Base.getindex(g::Union{GtkScale, GtkAdjustment}, ::Type{T} = Number) where T <: Number = Gtk4.value(g)
Base.getindex(g::GtkCheckButton, ::Type{Bool}) = g.active
Base.getindex(g::GtkEntry, ::Type{String}) = g.text
Base.getindex(g::GtkLabel, ::Type{String}) = g.label
Base.getindex(g::Union{GtkEntry, GtkLabel}, t::Type = String) = parse(t, g[String])
Base.getindex(g::GtkComboBoxText, ::Type{String} = String) = Gtk4.active_text(g)
Base.getindex(g::GtkComboBoxText, ::Type{T}) where T <: Integer = g.active

Base.setindex!(g::GtkComboBoxText, v::Integer) = g.active = v
Base.setindex!(g::GtkComboBoxText, v::String) = Gtk4.active_text(g, v)
Base.setindex!(g::GtkLabel, v) = g.label = string(v)
Base.setindex!(g::GtkEntry, v) = g.text = string(v)
Base.setindex!(g::Union{GtkScale, GtkAdjustment}, v) = Gtk4.value(g, v)
Base.setindex!(g::GtkCheckButton, v) = g.active = v

function makewidgetwithtitle(widget, label::AbstractObservable)
    grid = GtkGrid()
    lbl = GtkLabel(""; hexpand=true)
    on(l -> Gtk4.markup(lbl, "<b>$l</b>"), label; update=true)
    grid[1, 1] = lbl
    grid[1, 2] = widget
    return grid
end

function makewidgetwithtitle(widget, label)
    grid = GtkGrid()
    lbl = GtkLabel(label; hexpand=true)
    Gtk4.markup(lbl, "<b>$label</b>")
    grid[1, 1] = lbl
    grid[1, 2] = widget
    return grid
end

makewidgetswithtitle(widgets, labels) = [makewidgetwithtitle(widgets[i], labels[i]) for i in eachindex(widgets)]

function buttonwithimage(label, img)
    box = GtkBox(:h; hexpand=true)
    append!(box, GtkLabel(label; hexpand=true), img)
    return GtkButton(box)
end

Base.append!(b::GtkWidget, items) = foreach(x -> push!(b, x), items)
Base.append!(b::GtkWidget, items...) = foreach(x -> push!(b, x), items)