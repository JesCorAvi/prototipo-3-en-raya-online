extends Node2D

@onready var circle_panel: Panel = $Panel
@onready var label: Label = $Label

func setup_cursor(symbol_name: String):
	label.text = "Jugador " + symbol_name
	
	var color: Color
	if symbol_name == "X":
		color = Color.RED
	elif symbol_name == "O":
		color = Color.BLUE
	else:
		color = Color.WHITE
	
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = color
	stylebox.set_corner_radius_all(90)
	
	circle_panel.add_theme_stylebox_override("panel", stylebox)
