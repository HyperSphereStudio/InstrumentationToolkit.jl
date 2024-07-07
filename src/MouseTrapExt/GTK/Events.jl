Makie.window_open(scene::Scene, ::GLArea) = scene.events.window_open[] = true
Makie.disconnect!(screen::ScreenType, ::typeof(Makie.window_open)) = ()
Makie.hasfocus(scene::Scene, ::GLArea) = scene.events.hasfocus[] = true
Makie.unicode_input(::Scene, ::GLArea) = ()
Makie.dropped_files(::Scene, ::GLArea) = ()
Makie.entered_window(::Scene, ::GLArea) = ()
Makie.disconnect!(screen::ScreenType, ::T) where T <: Function = ()

function Makie.mouse_buttons(scene::Scene, gla::GLArea)
    event = scene.events.mousebutton
    g = GestureClick(gla, 0)
	
	4.on_pressed(_mouse_event_cb, g, (event, Mouse.press))
	4.on_released(_mouse_event_cb, g, (event, Mouse.release))
end

function Makie.keyboard_buttons(scene::Scene, gla::GLArea)
	event = scene.events.keyboardbutton
    e = EventControllerKey(gla)
	connect_signal_key_pressed!(_key_pressed_cb, event)
	connect_signal_key_released!(_key_pressed_cb, event)
	add_controller!(gla, key_controller)
	4.on_key_pressed(_key_pressed_cb, e, event)
	4.on_key_released(_key_released_cb, e, event)
end

function Makie.mouse_position(scene::Scene, screen::ScreenType)
    gla = screen.glscreen
    g = 4.EventControllerMotion(gla)
    event = scene.events.mouseposition
    hasfocus = scene.events.hasfocus
    entered = scene.events.entered_window

	4.on_motion(_mouse_motion_cb, g, (hasfocus, event))
	4.on_enter(_mouse_enter_cb, g, entered)
	4.on_leave(_mouse_leave_cb, g, entered)
end
Makie.disconnect!(screen::ScreenType, ::typeof(Makie.mouse_position)) = ()

function Makie.scroll(scene::Scene, gla::GLArea)
	event = scene.events.scroll
    e = EventControllerScroll(4.EventControllerScrollFlags_HORIZONTAL | 4.EventControllerScrollFlags_VERTICAL, gla)
    id = 4.on_scroll(_scroll_cb, e, (event, gla))
end

function _scroll_cb(ptr, dx, dy, user_data)
    event, window = user_data
    event[] = (dx, dy)
    4.queue_render(window)
    Cint(0)
end

function _mouse_motion_cb(ptr, x, y, user_data)
    ec = convert(EventControllerMotion, ptr)
    glarea = 4.widget(ec)
    hasfocus, event = user_data
    if hasfocus[]
        event[] = GLMakie.correct_mouse(glarea, x,y)
        4.queue_render(glarea)
    end
    nothing
end

function _mouse_enter_cb(ptr, x, y, entered)
    entered[] = true
    nothing
end

function _mouse_leave_cb(ptr, entered)
    entered[] = false
    nothing
end

function _mouse_event_cb(ptr, n_press, x, y, user_data)
    event, event_type = user_data
    controller = convert(EventController, ptr)
    glarea = 4.widget(controller)
    b = 4.current_button(controller)
    b > 3 && return nothing
    event[] = MouseButtonEvent(_translate_mousebutton(b), event_type)
    4.queue_render(glarea)
    nothing
end

function _key_pressed_cb(self, key, modifier)
    event[] = KeyEvent(Keyboard.Button(_translate_keyval(keyval)), Keyboard.Action(Int(1)))
    Cint(0)
end