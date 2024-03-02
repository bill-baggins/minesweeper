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
	^WidgetContainer,
}

Widget :: struct {
	bb: rl.Rectangle,
}

Button :: struct($T: typeid) {
	using widget: Widget,
	action: proc(data: T),
}

button_free :: proc(button: ^Button) {

}

Label :: struct {
	using widget: Widget,
}

label_free :: proc(label : ^Label) {

}

WidgetContainer :: struct {
	using widget: Widget,
	widgets: [dynamic]WidgetType,
}

widget_container_free :: proc(widget_container: ^WidgetContainer) {

}

widget_free :: proc{ button_free, label_free, widget_container_free }
