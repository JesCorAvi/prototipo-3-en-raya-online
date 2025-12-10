extends RigidBody2D

@export var player_symbol: int = 1:
	set(value):
		player_symbol = value
		if is_inside_tree():
			update_symbol()

@export var original_position: Vector2

@export var is_dragging: bool = false

var piece_size: float = 128.0 

var current_cell_index: int = -1 
var is_returning: bool = false
var offset: Vector2 = Vector2.ZERO
var drag_target_position: Vector2 = Vector2.ZERO
var return_target_pos: Vector2

var main_script = null

var _local_dragging_state: bool = false

@onready var panel: Panel = $Panel
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	if not main_script:
		main_script = get_node_or_null("/root/Main")
	
	if main_script and "current_piece_size" in main_script:
		piece_size = main_script.current_piece_size

	if original_position == Vector2.ZERO:
		original_position = global_position
		
	return_target_pos = original_position
	set_as_top_level(true)
	
	apply_visual_size()
	update_symbol()
	
	set_multiplayer_authority(1)
	
	lock_rotation = true
	freeze = false
	z_index = 0

func apply_visual_size():
	if not panel or not collision_shape: return
	
	panel.custom_minimum_size = Vector2(piece_size, piece_size)
	panel.size = Vector2(piece_size, piece_size)
	panel.position = Vector2(-piece_size / 2.0, -piece_size / 2.0)
	

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
	
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = piece_size / 2.0
	collision_shape.position = Vector2.ZERO

func _physics_process(_delta):

	if _local_dragging_state:
		freeze = true
		global_position = drag_target_position
		linear_velocity = Vector2.ZERO
		collision_shape.disabled = true
		is_dragging = true
	else:
		collision_shape.disabled = is_dragging
		
		if is_multiplayer_authority():
			if not is_returning and current_cell_index == -1:
				linear_velocity = Vector2.ZERO

@rpc("any_peer", "call_local")
func request_drag_authority():
	var sender_id = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server(): return
	
	if main_script.lobby_players.has(sender_id):
		if main_script.lobby_players[sender_id].team == player_symbol:
			rpc("set_new_authority", sender_id)

@rpc("any_peer", "call_local")
func set_new_authority(new_auth_id: int):
	if not multiplayer.is_server() and multiplayer.get_remote_sender_id() != 1: 
		return
	set_multiplayer_authority(new_auth_id)

func update_authority():
	pass

func update_symbol():
	var symbol := ""
	var color := Color.WHITE
	var panel_color := Color.WHITE

	match player_symbol:
		1: 
			symbol = "X"
			color = Color.BLUE
			panel_color = Color(0.8, 0.8, 1)
		2: 
			symbol = "O"
			color = Color.RED
			panel_color = Color(1, 0.8, 0.8)
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
	
	var my_team = 0
	if main_script.lobby_players.has(my_id):
		my_team = main_script.lobby_players[my_id].team
	
	if my_team != player_symbol: return 
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if panel.get_global_rect().has_point(event.global_position):
					
					_local_dragging_state = true
					
					if get_multiplayer_authority() != my_id:
						rpc_id(1, "request_drag_authority")
					
					is_returning = false 
					z_index = 99
					
					offset = event.global_position - global_position
					drag_target_position = _clamp_vector(event.global_position - offset)
					
					freeze = true 
					get_viewport().set_input_as_handled()
			else:
				if _local_dragging_state:
					_local_dragging_state = false
					is_dragging = false 
					z_index = 0
					
					var drop_pos = event.global_position
					var new_cell_index = check_drop_target(drop_pos)
					
					if new_cell_index != -1:
						var is_occupied = false
						if not main_script.board.is_empty() and new_cell_index < main_script.board.size():
							is_occupied = main_script.board[new_cell_index] != main_script.EMPTY
						
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

	elif event is InputEventMouseMotion and _local_dragging_state:
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
	
	if current_cell_index != -1 and current_cell_index < main_script.cell_nodes.size():
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
