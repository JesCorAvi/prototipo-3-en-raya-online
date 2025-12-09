extends RigidBody2D

@export var player_symbol: int = 1
@export var is_dragging: bool = false

var current_cell_index: int = -1 
var original_position: Vector2
var is_returning: bool = false
var offset: Vector2 = Vector2.ZERO
var drag_target_position: Vector2 = Vector2.ZERO
var last_global_pos: Vector2
var return_target_pos: Vector2
var highlight_material: ShaderMaterial

const PIECE_SIZE = 128.0

@onready var main_script = get_node("/root/Main")
@onready var panel: Panel = $Panel
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	original_position = global_position
	return_target_pos = original_position
	set_as_top_level(true)
	update_symbol()
	lock_rotation = true
	freeze = false
	z_index = 0

	var shader = load("res://shaders/outline_highlight.gdshader")
	if shader:
		highlight_material = ShaderMaterial.new()
		highlight_material.shader = shader
		highlight_material.set_shader_parameter("color", Color(1, 1, 0, 1))
		highlight_material.set_shader_parameter("width", 5.0)
		highlight_material.set_shader_parameter("pattern", 1)
		highlight_material.set_shader_parameter("add_margins", true)

	panel.mouse_entered.connect(_on_panel_hover.bind(true))
	panel.mouse_exited.connect(_on_panel_hover.bind(false))

	await get_tree().process_frame
	last_global_pos = global_position


func _physics_process(_delta):
	collision_shape.disabled = is_dragging
	
	if is_dragging:
		var direction = drag_target_position - global_position
		linear_velocity = direction * 25.0 
	else:
		linear_velocity = Vector2.ZERO

	last_global_pos = global_position

func _on_panel_hover(is_hovering: bool):
	if is_hovering and not is_dragging:
		panel.material = highlight_material
	else:
		panel.material = null

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
					panel.material = null
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

						var free_drop_pos = global_position + Vector2(64, 64)
						
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
		collision_shape.set_deferred("disabled", false)
		freeze = false
	)
