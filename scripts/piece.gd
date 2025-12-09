extends TextureRect

@onready var main_script = get_node("/root/Main")

@export var player_symbol: int = 1 

var original_position: Vector2
var is_dragging: bool = false
var offset: Vector2 = Vector2.ZERO 

func _ready():
	original_position = global_position
	mouse_filter = MOUSE_FILTER_PASS
	set_as_top_level(true)
	queue_redraw()
	
func _draw():
	var symbol = ""
	var color = Color.WHITE
	
	if player_symbol == 1:
		symbol = "X"
		color = Color.RED
	elif player_symbol == 2:
		symbol = "O"
		color = Color.BLUE
		
	if symbol.is_empty():
		return
		
	var font_to_use = get_theme_font("font", "Label")
	var draw_size = 64 

	if font_to_use:
		var text_size = font_to_use.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, draw_size)
		var draw_pos = (get_size() / 2) - (text_size / 2)
		
		draw_pos.y += text_size.y * 0.35 
		
		draw_string(font_to_use, draw_pos, symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, draw_size, color)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if get_global_rect().has_point(event.global_position):
					if main_script.player_symbol != player_symbol:
						return
						
					if main_script.get_my_pieces_left() <= 0:
						main_script.status_label.text = "¡Ya no te quedan piezas para colocar!"
						return
						
					is_dragging = true
					z_index = 10 
					offset = event.global_position - global_position
					get_viewport().set_input_as_handled()
			else:
				if is_dragging:
					is_dragging = false
					z_index = 0 
					
					var cell_index = check_drop_target(event.global_position)
					
					if cell_index != -1:
						# VERIFICACIÓN: Comprobar si la casilla está vacía
						if main_script.board[cell_index] == main_script.EMPTY:
							main_script.attempt_place_piece(cell_index)
							# CLAVE: Ocultar la pieza visual inmediatamente tras el intento de colocación
							hide() 
						else:
							# Informar que la casilla está ocupada
							main_script.status_label.text = "¡Esa casilla ya está ocupada!"

					# Siempre volvemos a la posición original.
					global_position = original_position
					
					get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		if is_dragging:
			global_position = event.global_position - offset
			get_viewport().set_input_as_handled()

func check_drop_target(drop_position: Vector2) -> int:
	var cell_nodes: Array = main_script.cell_nodes
	
	for i in range(cell_nodes.size()):
		var cell_node: Control = cell_nodes[i]
		
		var cell_rect = cell_node.get_global_rect()
		
		if cell_rect.has_point(drop_position):
			return i 
			
	return -1
