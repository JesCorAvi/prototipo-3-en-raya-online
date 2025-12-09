extends Node2D

const BOARD_SIZE = 9
const PLAYER_X = 1
const PLAYER_O = 2
const EMPTY = 0
const DEFAULT_PORT = 10567
const MAX_PLAYERS = 2
const MAX_PLAYER_PIECES = 3 
const CURSOR_SCENE_PATH = "res://scenes/Cursor.tscn"
const PIECE_SCENE_PATH = "res://scenes/piece.tscn"

var board: Array[int] = []
var player_symbol: int
var pieces_left_X: int = MAX_PLAYER_PIECES
var pieces_left_O: int = MAX_PLAYER_PIECES
var player_o_net_id: int = PLAYER_O
var is_game_active: bool = false
var remote_cursors: Dictionary = {}
var cursor_scene: PackedScene
var piece_scene: PackedScene
var cell_nodes: Array = []

@onready var grid_container: GridContainer = $GridContainer
@onready var status_label: Label = $StatusLabel
@onready var host_button: Button = $HostButton
@onready var join_button: Button = $JoinButton
@onready var ip_input: LineEdit = $IPAddress
@onready var result_label: Label = $ResultLabel
@onready var reset_timer: Timer = $ResetTimer
@onready var piece_container: Node = $PieceContainer

@onready var btn_add_x = $PieceContainer/AñadirX
@onready var btn_add_o = $PieceContainer/AñadirO
@onready var spawn_x_pos = $PieceContainer/SpawnX
@onready var spawn_o_pos = $PieceContainer/SpawnO

func _ready():
	if ResourceLoader.exists(CURSOR_SCENE_PATH):
		cursor_scene = load(CURSOR_SCENE_PATH)
	if ResourceLoader.exists(PIECE_SCENE_PATH):
		piece_scene = load(PIECE_SCENE_PATH)
	
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connection_failed.connect(_connection_failed)
	
	btn_add_x.pressed.connect(_on_add_piece_pressed.bind(PLAYER_X))
	btn_add_o.pressed.connect(_on_add_piece_pressed.bind(PLAYER_O))
	
	for i in range(BOARD_SIZE):
		cell_nodes.append(grid_container.get_child(i))

	grid_container.hide()
	result_label.hide()
	reset_game()

func _process(_delta):
	if multiplayer.has_multiplayer_peer() and is_game_active:
		var mouse_pos = get_viewport().get_mouse_position()
		rpc("send_cursor_position", mouse_pos)


func _on_add_piece_pressed(symbol: int):
	if not is_game_active: return
	rpc_id(1, "spawn_new_piece", symbol)

@rpc("any_peer", "call_local")
func spawn_new_piece(symbol: int):
	if not multiplayer.is_server(): return
	
	var new_piece = piece_scene.instantiate()
	new_piece.player_symbol = symbol
	
	var spawn_pos = Vector2.ZERO
	if symbol == PLAYER_X:
		spawn_pos = spawn_x_pos.position
	else:
		spawn_pos = spawn_o_pos.position
		
	spawn_pos += Vector2(randf_range(-10, 10), randf_range(-10, 10))
	
	new_piece.position = spawn_pos
	new_piece.original_position = spawn_pos
	
	piece_container.add_child(new_piece, true)
	
	var auth_id = PLAYER_X if symbol == PLAYER_X else player_o_net_id
	new_piece.set_multiplayer_authority(auth_id)


func _on_HostButton_pressed():
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(DEFAULT_PORT, MAX_PLAYERS) != OK:
		status_label.text = "Error al crear Host."
		return
		
	multiplayer.multiplayer_peer = peer
	player_symbol = PLAYER_X
	player_o_net_id = PLAYER_O
	status_label.text = "Host iniciado. Esperando jugador..."
	disable_network_buttons()

func _on_JoinButton_pressed():
	var peer = ENetMultiplayerPeer.new()
	var ip = ip_input.text if not ip_input.text.is_empty() else "127.0.0.1"
	if peer.create_client(ip, DEFAULT_PORT) != OK:
		status_label.text = "Error al crear Cliente."
		return

	multiplayer.multiplayer_peer = peer
	player_symbol = PLAYER_O
	status_label.text = "Conectando..."
	disable_network_buttons()

func _connection_failed():
	status_label.text = "Error de conexión."
	is_game_active = false
	reset_game(false)

func _player_connected(id: int):
	if multiplayer.is_server():
		if multiplayer.get_peers().size() == 1:
			status_label.text = "¡Juego en marcha!"
			grid_container.show()
			set_pieces_visible(true)
			is_game_active = true
			player_o_net_id = id
			apply_piece_authorities_local()
			rpc("sync_game_state", board, pieces_left_X, pieces_left_O, player_o_net_id)

func _player_disconnected(id: int):
	status_label.text = "Oponente desconectado."
	is_game_active = false
	player_o_net_id = PLAYER_O
	if remote_cursors.has(id):
		remote_cursors[id].queue_free()
		remote_cursors.erase(id)
	reset_game(false)

@rpc("any_peer")
func sync_game_state(new_board: Array[int], new_pieces_X: int, new_pieces_O: int, new_player_o_net_id: int): 
	board = new_board
	pieces_left_X = new_pieces_X
	pieces_left_O = new_pieces_O
	player_o_net_id = new_player_o_net_id
	
	update_board_ui()
	update_piece_counts_ui()
	disable_network_buttons()
	grid_container.show()
	set_pieces_visible(true)
	is_game_active = true
	apply_piece_authorities_local()

@rpc("any_peer", "unreliable")
func send_cursor_position(position: Vector2):
	if not cursor_scene: return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == multiplayer.get_unique_id(): return 
	
	if not remote_cursors.has(sender_id):
		var cursor_node = cursor_scene.instantiate()
		add_child(cursor_node)
		remote_cursors[sender_id] = cursor_node
		var symbol_name = "X" if sender_id == 1 else "O"
		cursor_node.setup_cursor(symbol_name)
		
	remote_cursors[sender_id].global_position = position

func apply_piece_authorities_local():
	if not multiplayer.has_multiplayer_peer(): return
	for piece in piece_container.get_children():
		if not piece is RigidBody2D: continue
		
		var target_id = PLAYER_X if piece.player_symbol == PLAYER_X else player_o_net_id
		piece.set_multiplayer_authority(target_id)

func attempt_place_piece(new_index: int, piece_path: String, target_pos: Vector2, old_index: int = -1):
	if not multiplayer.has_multiplayer_peer():
		status_label.text = "Primero debes unirte a un juego."
		return
		
	if board[new_index] != EMPTY and new_index != old_index:
		status_label.text = "Casilla ocupada."
		var p = get_node(piece_path)
		if p: p.return_to_last_valid_pos()
		return

	rpc("place_piece", new_index, player_symbol, piece_path, target_pos, old_index)

@rpc("any_peer", "call_local")
func place_piece(new_index: int, symbol: int, piece_path: String, target_pos: Vector2, old_index: int):
	if board[new_index] != EMPTY and new_index != old_index:
		return
		
	if old_index != -1:
		board[old_index] = EMPTY
	
	board[new_index] = symbol
	
	var piece_node: RigidBody2D = get_node(piece_path)
	if is_instance_valid(piece_node):
		piece_node.global_position = target_pos - Vector2(64, 64)
		piece_node.current_cell_index = new_index
		piece_node.freeze = true
		piece_node.is_dragging = false
		piece_node.is_returning = false
		piece_node.linear_velocity = Vector2.ZERO
		piece_node.z_index = 0
	
	update_board_ui()
	update_piece_counts_ui()
	
	if check_win(symbol):
		game_over(symbol)

func check_win(symbol: int) -> bool:
	var winning_lines = [
		[0, 1, 2], [3, 4, 5], [6, 7, 8],
		[0, 3, 6], [1, 4, 7], [2, 5, 8],
		[0, 4, 8], [2, 4, 6]           
	]
	for line in winning_lines:
		if board[line[0]] == symbol and board[line[1]] == symbol and board[line[2]] == symbol:
			return true
	return false

func game_over(winning_symbol: int):
	var result_text = "¡EMPATE!"
	var result_color = Color.WHITE
	if winning_symbol != 0:
		var winner_name = "X" if winning_symbol == PLAYER_X else "O"
		result_text = "¡GANA " + winner_name + "!"
		result_color = Color.RED
		if winning_symbol == player_symbol:
			result_color = Color.GREEN
	show_game_result(result_text, result_color)

func show_game_result(result_text: String, color: Color):
	status_label.text = ""
	result_label.text = result_text
	result_label.add_theme_color_override("font_color", color)
	result_label.show()
	reset_timer.start() 

func _on_ResetTimer_timeout():
	if multiplayer.is_server():
		reset_game(true)
		rpc("sync_game_state", board, pieces_left_X, pieces_left_O, player_o_net_id)
	else:
		reset_game(false)

func reset_game(keep_peer: bool = false):
	board.resize(BOARD_SIZE)
	board.fill(EMPTY)
	pieces_left_X = MAX_PLAYER_PIECES
	pieces_left_O = MAX_PLAYER_PIECES
	is_game_active = false
	
	update_board_ui()
	update_piece_counts_ui()
	
	result_label.hide()
	reset_timer.stop()
	
	for piece in piece_container.get_children():
		if piece is RigidBody2D:
			piece.current_cell_index = -1
			piece.freeze = false
			piece.is_returning = false
			piece.linear_velocity = Vector2.ZERO
			piece.global_position = piece.original_position 
			piece.z_index = 0
	
	if not keep_peer and multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	
	if not keep_peer or not multiplayer.has_multiplayer_peer():
		player_o_net_id = PLAYER_O
		remote_cursors.clear()
		enable_network_buttons()
		grid_container.hide()
		set_pieces_visible(false)
		status_label.text = "Presiona Crear Juego o Unirse para empezar."
	elif multiplayer.is_server() and keep_peer:
		status_label.text = "Juego reiniciado. Esperando al oponente..."

func update_board_ui():
	for i in range(BOARD_SIZE):
		var cell = cell_nodes[i]
		if cell is Button:
			cell.text = "" 

func update_piece_counts_ui():
	var my_pieces = get_my_pieces_left()
	var opponent_pieces = get_opponent_pieces_left()
	status_label.text = "Tus piezas: " + str(my_pieces) + " | Oponente: " + str(opponent_pieces)

func get_my_pieces_left() -> int:
	return pieces_left_X if player_symbol == PLAYER_X else pieces_left_O
	
func get_opponent_pieces_left() -> int:
	return pieces_left_O if player_symbol == PLAYER_X else pieces_left_X

func enable_network_buttons():
	host_button.show()
	join_button.show()
	ip_input.show()
	host_button.disabled = false
	join_button.disabled = false
	ip_input.editable = true

func disable_network_buttons():
	host_button.hide()
	join_button.hide()
	ip_input.hide()
	host_button.disabled = true
	join_button.disabled = true
	ip_input.editable = false

func set_pieces_visible(is_visible: bool):
	for child in piece_container.get_children():
		if child is CanvasItem:
			child.visible = is_visible
