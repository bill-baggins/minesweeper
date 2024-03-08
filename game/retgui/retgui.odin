package retgui

import rl "vendor:raylib"
import "core:fmt"

// To be implemented in Raylib (why do I do this to myself...)
// Button, Calendar, CheckBox, ComboBox, DateTimePicker, GroupBox, Label, ListBox, 
// TextBox NumberPicker (Updown Control), ProgressBar, RadioButton, TrackBar, TreeView, MenuBar
// WindowBox

// Why? Because its fun learning new things.
// Requires a parent-child hierarchy

WidgetType :: union {
	^Button,
	^Label,
}

Widget :: struct {
	name: string,
	bb: rl.Rectangle,
    bg_color: rl.Color,
	font: rl.Font,
	font_size: f32,
	texture: rl.Texture,
	_render_texture: rl.RenderTexture,
	_render_texture_rect: rl.Rectangle,
}

widget_set_font :: proc(widget: ^Widget, font: rl.Font) {
	widget.font = font
}

Button :: struct {
	using widget: Widget,
	text: cstring,
    text_color: rl.Color,
	action: proc(data: uintptr),
	data: uintptr,
}


// Creates a new button with a set bounding rectangle, text, and action.
button_new :: proc(
	name: string, 
	pos: rl.Vector2, 
	size: rl.Vector2, 
	text: cstring = "",
    text_color: rl.Color = rl.BLACK,
    bg_color: rl.Color = rl.BLUE, 
	font_size: f32 = 5., 
	action: proc(data: uintptr) = nil,
	data: uintptr = 0,
) -> ^Button 
{
	assert(size[0] > 0 && size[1] > 0)

	button : ^Button = new(Button)
	button.name = name
	button.bb = rl.Rectangle{pos[0], pos[1], size[0], size[1]}
	button.text = text
	button.font_size = font_size

	button_im := rl.GenImageColor(auto_cast size[0], auto_cast size[1], bg_color)
	defer rl.UnloadImage(button_im)

	button._render_texture = rl.LoadRenderTexture(auto_cast size[0], auto_cast size[1])
	button._render_texture_rect = {
		0,
		0,
		size[0],
		-size[1],
	}

    button.text_color = text_color
    button.bg_color = bg_color

	button.texture = rl.LoadTextureFromImage(button_im)
	button.action = action
	button.data = data

	return button
}

button_update_draw :: proc(button: ^Button, mouse_pos: rl.Vector2) {
	using button
	tint := rl.WHITE

	if rl.CheckCollisionPointRec(mouse_pos, bb) {
		tint -= 50
		tint[3] = 255

		if rl.IsMouseButtonReleased(.LEFT) {
			action(data)
		}
	} else {
		tint = rl.WHITE
	}

	text_draw_pos := rl.Vector2{
		(bb.width/2) - cast(f32)(rl.TextLength(text)* auto_cast (font_size/4)),
		(bb.height/2) - cast(f32)(font_size / 2.3),
	}

	// rl.DrawTextEx(font, text,  text_draw_pos, font_size, 1., rl.BLACK)
	// rl.DrawTextureRec(texture, bb, {bb.x, bb.y}, tint)

	rl.BeginTextureMode(_render_texture)
    rl.ClearBackground(bg_color)

	rl.DrawTextureRec(texture, bb, {}, rl.WHITE)
	rl.DrawTextEx(font, text, text_draw_pos, font_size, 1., text_color)

	rl.EndTextureMode()

	rl.DrawTextureRec(_render_texture.texture, _render_texture_rect, {bb.x, bb.y}, tint)
}	

button_free :: proc(button: ^Button) {
	using button

    fmt.println("Freeing memory for Button", button.name)

	rl.UnloadTexture(texture)
	rl.UnloadRenderTexture(_render_texture)
	free(button)
}

Label :: struct {
	using widget: Widget,
	text: cstring,
    text_color: rl.Color,
}

label_new :: proc(
	name: string, 
	pos: rl.Vector2, 
	size: rl.Vector2, 
	text: cstring = "", 
    text_color: rl.Color = rl.BLACK,
    bg_color: rl.Color = rl.Color{},
	font_size: f32 = 5., 
) -> ^Label 
{
	label : ^Label = new(Label)
	label.name = name

	label.bb = rl.Rectangle{pos[0], pos[1], size[0], size[1]}
	label.text = text

	label.font_size = font_size

	label_im := rl.GenImageColor(auto_cast size[0], auto_cast size[1], bg_color)
	defer rl.UnloadImage(label_im)

	label.texture = rl.LoadTextureFromImage(label_im)

	label._render_texture = rl.LoadRenderTexture(auto_cast size[0], auto_cast size[1])
	label._render_texture_rect = {
		0,
		0,
		size[0],
		-size[1],
	}

    label.text_color = text_color
    label.bg_color = bg_color

	return label
}

label_update_draw :: proc(label: ^Label, mouse_pos: rl.Vector2) {
	using label

	text_draw_pos := rl.Vector2{
		(bb.width/2) - cast(f32)(rl.TextLength(text) * auto_cast (font_size/4)),
		(bb.height/2) - cast(f32)(font_size / 2.3),
	}

	rl.BeginTextureMode(_render_texture)
    rl.ClearBackground(bg_color)

	rl.DrawTextureRec(texture, bb, {}, rl.WHITE)
	rl.DrawTextEx(font, text, text_draw_pos, font_size, 1., text_color)

	rl.EndTextureMode()

	rl.DrawTextureRec(_render_texture.texture, _render_texture_rect, {bb.x, bb.y}, rl.WHITE)
}

label_free :: proc(label : ^Label) {
	using label

    fmt.println("Freeing memory for Label", label.name)

	rl.UnloadRenderTexture(_render_texture)
	rl.UnloadTexture(texture)
	free(label)
}

widget_update_draw :: proc(widget: WidgetType, mouse_pos: rl.Vector2) {
	switch w in widget {
		case ^Button:
			button_update_draw(w, mouse_pos)
		case ^Label:
			label_update_draw(w, mouse_pos)
	}
}

widget_free :: proc(widget: WidgetType) {
	switch w in widget {
		case ^Button:
			button_free(w)
		case ^Label:
			label_free(w)
	}
}



// WidgetContainer :: struct {
// 	using widget: Widget,
// 	widgets: [dynamic]^Widget,
// }

// widget_container_new :: proc(bb: rl.Rectangle, font: rl.Font) -> ^WidgetContainer {
// 	wc : ^WidgetContainer = new(WidgetContainer)
// 	wc.bb = bb
// 	wc.font = font

// 	wc.widgets = make([dynamic]^Widget)

// 	return wc
// }

// widget_container_add :: proc(widget_container: ^WidgetContaier, widget: ^Widget) {
// 	using widget_container

// 	append(&widgets, widget)
// }

// widget_container_update_draw :: proc(widget_container: ^WidgetContainer, mouse_pos: rl.Vector2) {
// 	using widget_container

// 	for widget in widgets {
// 		widget_update_draw(widget, mouse_pos)
// 	}
// }

// widget_container_free :: proc(widget_container: ^WidgetContainer) {
// 	using widget_container

// 	for widget in widgets {
// 		widget_free(widget)
// 	}
// }