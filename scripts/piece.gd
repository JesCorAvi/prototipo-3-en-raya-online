extends RigidBody2D

@export var player_symbol: int = 1:
	set(value):
		player_symbol = value
		if is_inside_tree():
			update_symbol()

@export var original_position: Vector2
@export var is_dragging: bool = false

# Tamaño por defecto
var piece_size: float = 128.0 

var current_cell_index: int = -1 
var is_returning: bool = false
var offset: Vector2 = Vector2.ZERO
var drag_target_position: Vector2 = Vector2.ZERO
var return_target_pos: Vector2

var main_script = null

@onready var panel: Panel = $Panel
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	if not main_script:
		main_script = get_node_or_null("/root/Main")
	
	# Sincronizar tamaño con el Main
	if main_script and "current_piece_size" in main_script:
		piece_size = main_script.current_piece_size

	if original_position == Vector2.ZERO:
		original_position = global_position
		
	return_target_pos = original_position
	set_as_top_level(true)
	
	apply_visual_size()
	update_symbol()
	
	call_deferred("update_authority")
	
	lock_rotation = true
	freeze = false
	z_index = 0

func apply_visual_size():
	if not panel or not collision_shape: return
	
	# 1. Ajustar PANEL
	panel.custom_minimum_size = Vector2(piece_size, piece_size)
	panel.size = Vector2(piece_size, piece_size)
	panel.position = Vector2(-piece_size / 2.0, -piece_size / 2.0)
	
	# 2. LÓGICA DE TEXTO (CORREGIDA)
	# Si la pieza es menor a 100px (Conecta 4 es 64px), OCULTAMOS LA LETRA.
	# Si es grande (3 en Raya es 128px), la mostramos.
	if piece_size < 100:
		if label: label.visible = false
	else:
		if label:
			label.visible = true
			label.size = Vector2(piece_size, piece_size)
			label.position = panel.position
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", int(piece_size * 0.6))
	
	# 3. Ajustar COLISIÓN
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = piece_size / 2.0
	collision_shape.position = Vector2.ZERO

func _physics_process(_delta):
	if collision_shape:
		collision_shape.disabled = is_dragging
	
	if is_dragging:
		var direction = drag_target_position - global_position
		linear_velocity = direction * 25.0 
	else:
		linear_velocity = Vector2.ZERO

func update_authority():
	if not main_script: return
	var target_id = 1 
	if player_symbol == 2: 
		target_id = main_script.player_o_net_id
	set_multiplayer_authority(target_id)

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
			symbol = "?"
			panel_color = Color.GRAY

	if label:
		label.text = symbol
		label.add_theme_color_override("font_color", color)
	
	if panel:
		var stylebox := StyleBoxFlat.new()
		stylebox.bg_color = panel_color
		stylebox.set_corner_radius_all(int(piece_size / 2.0))
		panel.add_theme_stylebox_override("panel", stylebox)

func _input(event):
	if not multiplayer.has_multiplayer_peer(): return
	var my_id = multiplayer.get_unique_id()
	
	if get_multiplayer_authority() != my_id: return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if panel.get_global_rect().has_point(event.global_position):
					if main_script.player_symbol != player_symbol:
						main_script.status_label.text = "Solo puedes mover tus propias piezas."
						return
					
					is_dragging = true
					is_returning = false 
					z_index = 99
					
					offset = event.global_position - global_position
					drag_target_position = _clamp_vector(event.global_position - offset)
					
					freeze = false 
					get_viewport().set_input_as_handled()
			else:
				if is_dragging:
					is_dragging = false
					z_index = 0
					
					var drop_pos = event.global_position
					var new_cell_index = check_drop_target(drop_pos)
					
					if new_cell_index != -1:
						var is_occupied = main_script.board[new_cell_index] != main_script.EMPTY
						var is_same_cell = (new_cell_index == current_cell_index)
						
						if is_occupied and not is_same_cell:
							main_script.status_label.text = "¡Casilla ocupada!"
							return_to_last_valid_pos()
						else:
							var cell_node = main_script.cell_nodes[new_cell_index]
							var target_pos = cell_node.get_global_rect().get_center()
							main_script.attempt_place_piece(new_cell_index, get_path(), target_pos, current_cell_index)
					else:
						var free_drop_pos = original_position if original_position != Vector2.ZERO else global_position
						main_script.attempt_place_piece(-1, get_path(), free_drop_pos, current_cell_index)
						
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_dragging:
		drag_target_position = _clamp_vector(event.global_position - offset)
		get_viewport().set_input_as_handled()

func _clamp_vector(target: Vector2) -> Vector2:
	var vp_size = get_viewport_rect().size
	return Vector2(
		clamp(target.x, 0, vp_size.x - piece_size),
		clamp(target.y, 0, vp_size.y - piece_size)
	)

func check_drop_target(drop_position: Vector2) -> int:
	for i in range(main_script.cell_nodes.size()):
		if main_script.cell_nodes[i].get_global_rect().has_point(drop_position):
			return i
	return -1

func return_to_last_valid_pos():
	is_returning = true
	freeze = true 
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	if current_cell_index != -1:
		var cell = main_script.cell_nodes[current_cell_index]
		var center = cell.get_global_rect().get_center()
		return_target_pos = center 
	else:
		return_target_pos = original_position

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", return_target_pos, 0.3)
	
	tween.tween_callback(func():
		is_returning = false
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
		freeze = false
	)
