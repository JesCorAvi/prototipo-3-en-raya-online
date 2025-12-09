extends RigidBody2D

@onready var main_script = get_node("/root/Main")
@onready var panel: Panel = $Panel
@onready var label: Label = $Label

@export var player_symbol: int = 1 # 1 = X, 2 = O

var original_position: Vector2
var is_dragging: bool = false
var offset: Vector2 = Vector2.ZERO
var last_global_pos: Vector2 # Para el cálculo de la inercia


func _ready():
	original_position = global_position
	set_as_top_level(true)
	update_symbol()
	
	lock_rotation = true
	freeze = false # Cuerpo activo (equivale al antiguo MODE_RIGID)
	
	await get_tree().process_frame
	last_global_pos = global_position


func update_symbol():
	var symbol := ""
	var color := Color.WHITE
	var panel_color := Color.WHITE

	match player_symbol:
		1:
			symbol = "X"
			color = Color.RED
			panel_color = Color(1, 0.8, 0.8)
		2:
			symbol = "O"
			color = Color.BLUE
			panel_color = Color(0.8, 0.8, 1)
		_:
			symbol = ""
			panel_color = Color.WHITE

	label.text = symbol
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Configurar estilo visual del Panel
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = panel_color
	stylebox.corner_radius_top_left = 12
	stylebox.corner_radius_top_right = 12
	stylebox.corner_radius_bottom_left = 12
	stylebox.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", stylebox)


func _physics_process(delta):
	# Calcula la velocidad (para la inercia) solo mientras se arrastra
	if is_dragging:
		linear_velocity = (global_position - last_global_pos) / delta
	
	last_global_pos = global_position


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Verificar si se hizo clic dentro del Panel
				if panel.get_global_rect().has_point(event.global_position):
					if main_script.player_symbol != player_symbol:
						main_script.status_label.text = "Solo puedes mover tus propias piezas."
						return
					
					if main_script.get_my_pieces_left() <= 0:
						main_script.status_label.text = "¡Ya no te quedan piezas para colocar!"
						return
					
					is_dragging = true
					z_index = 10
					offset = event.global_position - global_position
					
					# Congelar la física mientras se arrastra
					freeze = true
					linear_velocity = Vector2.ZERO
					angular_velocity = 0.0
					
					get_viewport().set_input_as_handled()
			else:
				if is_dragging:
					is_dragging = false
					z_index = 0

					var cell_index = check_drop_target(event.global_position)
					
					# Reactivar la física
					freeze = false
					
					if cell_index != -1:
						if main_script.board[cell_index] == main_script.EMPTY:
							main_script.attempt_place_piece(cell_index)
						else:
							main_script.status_label.text = "¡Esa casilla ya está ocupada!"
					
					# Si no se colocó o la celda está ocupada, la pieza vuelve a su posición original
					if cell_index == -1 or main_script.board[cell_index] != main_script.EMPTY:
						global_position = original_position
						linear_velocity = Vector2.ZERO
					
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_dragging:
		global_position = event.global_position - offset
		get_viewport().set_input_as_handled()


func check_drop_target(drop_position: Vector2) -> int:
	var cell_nodes: Array = main_script.cell_nodes
	for i in range(cell_nodes.size()):
		var cell_node: Control = cell_nodes[i]
		if cell_node.get_global_rect().has_point(drop_position):
			return i
	return -1
