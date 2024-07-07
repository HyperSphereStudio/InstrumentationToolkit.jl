using Mousetrap: Label, Button
using Observables

function Observables.connect!(w, o::AbstractObservable{T}) where T
  done = Ref(false)
  on(w) do w
    if !done[]
        done[] = true
        o[] = w[]
        done[] = false
    end
	return nothing
  end
  on(o) do val
     if !done[]
        done[] = true
        w[] = val
        done[] = false
     end
	 return nothing
   end
end

function Observables.observe(w; ignore_equal_values::Bool=false)
	connect!(w, Observable(w; ignore_equal_values=ignore_equal_values))
end

Base.getindex(w::Scale) = get_value(w)
Base.setindex!(w::Scale, x::Number) = set_value!(w, x)
Observables.on(f, w::Scale) = connect_signal_value_changed!(x -> (f(w[]); return nothing), w)
Observables.notify(w::Scale) = emit_signal_value_changed(w)

Base.getindex(w::Label) = get_text(w)
Base.setindex!(w::Label, x::String) = set_text!(w, x)
Observables.on(f, w::Label) = ()
Observables.notify(w::Label) = ()

Base.getindex(w::Button) = false
Base.setindex!(w::Button, x::Bool) = ()
Observables.on(f, w::Button) = connect_signal_clicked!(x -> (f(w); return nothing), w)
Observables.notify(w::Button) = emit_signal_clicked(w)

Base.getindex(w::ToggleButton) = get_is_active(w)
Base.setindex!(w::ToggleButton, x::Bool) = set_is_active!(w, x)
Observables.on(f, w::ToggleButton) = connect_signal_toggled!(x -> (f(w[]); return nothing), w)
Observables.notify(w::ToggleButton) = emit_signal_toggled(w)

Base.getindex(w::Switch) = get_is_active(w)
Base.setindex!(w::Switch, x::Bool) = set_is_active!(w, x)
Observables.on(f, w::Switch) = connect_signal_switched!(x -> (f(w[]); return nothing), w)
Observables.notify(w::Switch) = emit_signal_switched(w)

Base.getindex(w::SpinButton) = get_value(w)
Base.setindex!(w::SpinButton, x::Number) = set_value!(w, x)
Observables.on(f, w::SpinButton) = connect_signal_value_changed!(x -> (f(w[]); return nothing), w)
Observables.notify(w::SpinButton) = emit_signal_value_changed(w)

Base.getindex(w::LevelBar) = get_value(w)
Base.setindex!(w::LevelBar, x::Number) = set_value!(w, x)
Observables.on(f, w::LevelBar) = ()
Observables.notify(w::LevelBar) = ()

Base.getindex(w::ProgressBar) = get_fraction(w)
Base.setindex!(w::ProgressBar, x::Number) = set_fraction!(w, x)
Observables.on(f, w::ProgressBar) = ()
Observables.notify(w::ProgressBar) = ()

Base.getindex(w::Spinner) = get_is_spinning(w)
Base.setindex!(w::Spinner, x::Bool) = set_is_spinning!(w, x)
Observables.on(f, w::Spinner) = ()
Observables.notify(w::Spinner) = ()

Base.getindex(w::Entry) = get_text(w)
Base.setindex!(w::Entry, x::String) = set_text!(w, x)
Observables.on(f, w::Entry) = connect_signal_activate!(x -> (f(w[]); return nothing), w)
Observables.notify(w::Entry) = emit_signal_activate(w)