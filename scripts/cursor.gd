extends Node2D

@onready var circle_panel: Panel = $Panel
@onready var label: Label = $Label

func set_cursor_info(p_name: String, p_color: Color):
	label.text = p_name
	# Si el nombre está vacío, ocultamos el label
	label.visible = not p_name.is_empty()
	
	var style = circle_panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.bg_color = p_color
	else:
		var new_style = StyleBoxFlat.new()
		new_style.bg_color = p_color
		new_style.set_corner_radius_all(90)
		circle_panel.add_theme_stylebox_override("panel", new_style)
