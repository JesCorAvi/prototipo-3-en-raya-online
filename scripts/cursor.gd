extends Node2D

@onready var circle_panel: Panel = $Panel
@onready var label: Label = $Label


var _style_is_unique: bool = false


func _ready():
	_make_style_unique()

func _make_style_unique():
	if _style_is_unique: return
	

	var new_style = StyleBoxFlat.new()
	new_style.set_corner_radius_all(90)
	new_style.bg_color = Color.WHITE 
	
	circle_panel.add_theme_stylebox_override("panel", new_style)
	
	_style_is_unique = true

func set_cursor_info(p_name: String, p_color: Color):
	label.text = p_name
	label.visible = not p_name.is_empty()
	
	_make_style_unique()
	
	var style = circle_panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.bg_color = p_color
