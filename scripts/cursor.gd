extends Node2D

@onready var circle_panel: Panel = $Panel # Asumimos que el Panel se llama "Panel"
@onready var label: Label = $Label

# Configura el color y el texto del cursor (X o O)
func setup_cursor(symbol_name: String):
	label.text = "Jugador " + symbol_name
	
	var color: Color
	if symbol_name == "X":
		color = Color.RED
	elif symbol_name == "O":
		color = Color.BLUE
	else:
		color = Color.WHITE
	
	# Creamos un StyleBoxFlat para modificar el color del Panel en tiempo de ejecución
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = color
	# Asumimos que quieres que el Panel se vea como un círculo (ajustar el radio)
	stylebox.corner_radius_top_left = 50 
	stylebox.corner_radius_top_right = 50
	stylebox.corner_radius_bottom_left = 50
	stylebox.corner_radius_bottom_right = 50
	
	circle_panel.add_theme_stylebox_override("panel", stylebox)
