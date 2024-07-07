GLMakie.was_destroyed(gla::GtkGLArea) = Gtk4.G_.in_destruction(gla)
GLMakie.was_destroyed(screen::ScreenType) = GLMakie.was_destroyed(screen.glscreen)
Base.isopen(gla::GtkGLArea) = !GLMakie.was_destroyed(gla)

ShaderAbstractions.native_context_alive(a::GtkGLArea) = isopen(a)
ShaderAbstractions.native_switch_context!(a::GtkGLArea) = Gtk4.make_current(a)
GLMakie.framebuffer_size(gla::GtkGLArea) = size(gla) .* GLMakie.scale_factor(gla)
GLMakie.resize!(gla::GtkGLArea, w, h) = gla
Makie.to_native(gla::GtkGLArea) = gla

function GLMakie.scale_factor(gla::GtkGLArea)
    f = Gtk4.scale_factor(gla)
    (f, f)
end

function calc_dpi(m::GdkMonitor)
    g = Gtk4.geometry(m)
    wdpi = g.width/(Gtk4.width_mm(m)/25.4)
    hdpi = g.height/(Gtk4.height_mm(m)/25.4)
    min(wdpi,hdpi)
end

function GLMakie.correct_mouse(gla::GtkGLArea, w, h)
    fb = GLMakie.framebuffer_size(gla)
    s = Gtk4.scale_factor(gla)
    (w * s, fb[2] - (h * s))
end

function GLMakie.set_screen_visibility!(gla::GtkGLArea, b::Bool)
    if b
        Gtk4.show(gla)
    else
        Gtk4.hide(gla)
    end
end