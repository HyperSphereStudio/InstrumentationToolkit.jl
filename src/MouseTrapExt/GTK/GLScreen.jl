using Mousetrap

const ScreenType = GLMakie.Screen{GLArea}

mutable struct ScreenState
    screen::ScreenType
    fb_id::Ref{Int}
    realize_count::Int
end

const SCREEN_STATES = Dict{UInt64, ScreenState}()

getscreenstate(gla) = SCREEN_STATES[hash(gla)]
hasscreenstate(gla) = haskey(SCREEN_STATES, hash(gla))

function GLScreen(gla; screen_config...)
	screen_config = Makie.merge_screen_config(GLMakie.ScreenConfig, Dict{Symbol, Any}(screen_config...))
    screen_config.render_on_demand = true

	set_auto_render!(gla, false)
	connect_signal_render!(on_gla_render, gla)
	connect_signal_realize!(on_gla_realize, gla)
	connect_signal_unrealize!(on_gla_realize, gla)
	
	gla
end

Base.display(gla::GLArea, scene; attr...) = begin 
    Makie.update_state_before_display!(scene)
    display(getscreenstate(gla).screen, scene; attr...)
end

function Base.resize!(screen::ScreenType, w::Int, h::Int)
	window = GLMakie.to_native(screen)
    (w > 0 && h > 0 && isopen(window)) || return nothing
    
    ShaderAbstractions.switch_context!(window)
    winscale = screen.scalefactor[] / get_scale_factor(window)
    winw, winh = round.(Int, winscale .* (w, h))

    fbscale = screen.px_per_unit[]
    fbw, fbh = round.(Int, fbscale .* (w, h))
    resize!(screen.framebuffer, fbw, fbh)
end

function Makie.window_area(scene::Scene, screen::ScreenType)
	gl = screen.glscreen
    winscale = screen.scalefactor[] / get_scale_factor(gl)
    area = scene.events.window_area
    dpi = scene.events.window_dpi
	connect_signal_resize!(_glarea_resize_cb, gl, (dpi, area, winscale))
    queue_render(screen.glscreen)
end
Makie.disconnect!(screen::ScreenType, ::typeof(window_area)) = ()

function on_gla_render(gla, context)
	if hasscreenstate(gla)
		ss = getscreenstate(gla)
		ss.screen.render_tick[] = nothing
		ss.fb_id[] = glGetIntegerv(GL_FRAMEBUFFER_BINDING)
		GLMakie.render_frame(ss.screen)
	end
	return Cint(true)
end

function _glarea_resize_cb(aptr, w, h, user_data)
    dpi, area, winscale = user_data
	
	dpi[] = calc_dpi(m)
	
    winw, winh = round.(Int, (w, h) ./ winscale )
    area[] = Recti(minimum(area[]), winw, winh)
    nothing
end

function on_gla_realize(self, context)
    if hasscreenstate(ptr)
        getscreenstate(ptr).realize_count += 1
    else
        begin
            try 
                screen_config = context
                shader_cache = GLAbstraction.ShaderCache(gla)
                ShaderAbstractions.switch_context!(gla)
                fb = GLMakie.GLFramebuffer((500, 500))
                fb_id = Ref(0)
    
                postprocessors = [screen_config.ssao ? GLMakie.ssao_postprocessor(fb, shader_cache) : GLMakie.empty_postprocessor(),
                                  screen_config.oit ? GLMakie.OIT_postprocessor(fb, shader_cache) : GLMakie.empty_postprocessor(),
                                  screen_config.fxaa ? GLMakie.fxaa_postprocessor(fb, shader_cache) : GLMakie.empty_postprocessor(), 
                                  GLMakie.to_screen_postprocessor(fb, shader_cache, fb_id)]
                    
                screen = GLMakie.Screen(
                    gla, shader_cache, fb,
                    screen_config, false,
                    nothing,
                    Dict{WeakRef, GLMakie.ScreenID}(),
                    GLMakie.ScreenArea[],
                    Tuple{GLMakie.ZIndex, GLMakie.ScreenID, GLMakie.RenderObject}[],
                    postprocessors,
                    Dict{UInt64, GLMakie.RenderObject}(),
                    Dict{UInt32, Makie.AbstractPlot}(),
                    false,
                )
        
                screen.scalefactor[] = !isnothing(screen_config.scalefactor) ? screen_config.scalefactor : get_scale_factor(gla)
                screen.px_per_unit[] = !isnothing(screen_config.px_per_unit) ? screen_config.px_per_unit : screen.scalefactor[]
    
                SCREEN_STATES[hash(gla)] = ScreenState(screen, fb_id, 1)
                queue_render(gla)
            catch e
                showerror(stdout, e)
                throw(e)
            end
        end
    end
    

    nothing
end

function on_gla_unrealize(gla, glaObject)
    if hasscreenstate(gla)
        try
            ss = getscreenstate(gla)
            ss.realize_count -= 1
            if ss.realize_count == 0

                screen = ss.screen
                GLMakie.set_screen_visibility!(screen, false)
                GLMakie.stop_renderloop!(screen; close_after_renderloop=false)
                empty!(screen)
                GLMakie.set_screen_visibility!(screen, false)

                delete!(SCREEN_STATES, hash(gla))
            end
        catch e
            showerror(stdout, e)
            throw(e)
        end
    end
    nothing
end