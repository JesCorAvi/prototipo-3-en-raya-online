extends RigidBody2D

# Setter: Actualiza visuales inmediatamente al recibir datos
@export var player_symbol: int = 1:
	set(value):
		player_symbol = value
		if is_inside_tree():
			update_symbol()

@export var original_position: Vector2 # Asegúrate de añadir esto al Synchronizer también

@export var is_dragging: bool = false

var current_cell_index: int = -1 
var is_returning: bool = false
var offset: Vector2 = Vector2.ZERO
var drag_target_position: Vector2 = Vector2.ZERO
var last_global_pos: Vector2
var return_target_pos: Vector2

const PIECE_SIZE = 128.0

var main_script = null

@onready var panel: Panel = $Panel
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	if not main_script:
		main_script = get_node_or_null("/root/Main")
	
	# Si original_position no se sincronizó (es 0,0), usamos la posición actual
	if original_position == Vector2.ZERO:
		original_position = global_position
		
	return_target_pos = original_position
	set_as_top_level(true)
	
	update_symbol()
	
	# SOLUCIÓN MAESTRA:
	# Usamos call_deferred para esperar a que termine la sincronización del Spawner.
	# Así recibimos la posición correcta (Spawn) ANTES de reclamar la autoridad.
	call_deferred("update_authority")
	
	lock_rotation = true
	freeze = false
	z_index = 0

func _physics_process(_delta):
	if collision_shape:
		collision_shape.disabled = is_dragging
	
	if is_dragging:
		var direction = drag_target_position - global_position
		linear_velocity = direction * 25.0 
	else:
		linear_velocity = Vector2.ZERO

	last_global_pos = global_position

func update_authority():
	if not main_script: return
	
	var target_id = 1 # Por defecto Servidor
	
	# Si es pieza O (jugador 2), la autoridad es el cliente O
	if player_symbol == 2: 
		target_id = main_script.player_o_net_id
	
	set_multiplayer_authority(target_id)

func update_symbol():
	var symbol := ""
	var color := Color.WHITE
	var panel_color := Color.WHITE

	match player_symbol:
		1: # PLAYER_X
			symbol = "X"
			color = Color.RED
			panel_color = Color(1, 0.8, 0.8)
		2: # PLAYER_O
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
		stylebox.set_corner_radius_all(12)
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
					if panel: panel.material = null
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
						# Soltar fuera (volver al spawn)
						var free_drop_pos = Vector2.ZERO
						if original_position != Vector2.ZERO:
							free_drop_pos = original_position
						else:
							free_drop_pos = global_position # Fallback
						
						main_script.attempt_place_piece(-1, get_path(), free_drop_pos, current_cell_index)
						
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_dragging:
		drag_target_position = _clamp_vector(event.global_position - offset)
		get_viewport().set_input_as_handled()

func _clamp_vector(target: Vector2) -> Vector2:
	var vp_size = get_viewport_rect().size
	return Vector2(
		clamp(target.x, 0, vp_size.x - PIECE_SIZE),
		clamp(target.y, 0, vp_size.y - PIECE_SIZE)
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
		return_target_pos = center - Vector2(PIECE_SIZE/2.0, PIECE_SIZE/2.0)
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
