extends Node2D

enum GameType { TIC_TAC_TOE = 1, CONNECT_4 = 2 }
var current_game_type = GameType.TIC_TAC_TOE

const TTT_COLS = 3
const TTT_ROWS = 3
const TTT_WIN_LEN = 3
const PIECE_SIZE_TTT = 128.0 

const C4_COLS = 7
const C4_ROWS = 6
const C4_WIN_LEN = 4
const PIECE_SIZE_C4 = 64.0 

var current_cols = TTT_COLS
var current_rows = TTT_ROWS
var current_win_len = TTT_WIN_LEN
var current_piece_size = PIECE_SIZE_TTT

const PLAYER_X = 1
const PLAYER_O = 2
const EMPTY = 0
const DEFAULT_PORT = 10567
const MAX_PLAYERS = 2
const MAX_PIECES_TTT = 5
const MAX_PIECES_C4 = 21 

const CURSOR_SCENE_PATH = "res://scenes/cursor.tscn"
const PIECE_SCENE_PATH = "res://scenes/piece.tscn"

var board: Array[int] = []
var player_symbol: int
var pieces_left_X: int = MAX_PIECES_TTT
var pieces_left_O: int = MAX_PIECES_TTT
var player_o_net_id: int = PLAYER_O
var is_game_active: bool = false
var remote_cursors: Dictionary = {}
var cursor_scene: PackedScene
var piece_scene: PackedScene
var cell_nodes: Array = [] # Referencia dinámica a los botones de la cuadrícula activa

# --- NODOS UI Y REFERENCIAS ---
@onready var grid_ttt: GridContainer = $tresenraya
@onready var grid_c4: GridContainer = $Conecta4
@onready var option_button: OptionButton = $OptionButton
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
	
	# Conexiones de red
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connection_failed.connect(_connection_failed)
	
	# Botones de generar piezas
	btn_add_x.pressed.connect(_on_add_piece_pressed.bind(PLAYER_X))
	btn_add_o.pressed.connect(_on_add_piece_pressed.bind(PLAYER_O))
	
	# Configurar selector de modo de juego
	option_button.item_selected.connect(_on_game_mode_selected)
	
	# Generar cuadrícula de Conecta 4
	_generate_connect4_grid()
	
	# Inicializar grupos de piezas originales
	for child in piece_container.get_children():
		if child is RigidBody2D:
			child.add_to_group("initial_pieces")
			if "original_position" in child:
				child.original_position = child.global_position

	# OCULTAR PIEZAS EN EL MENÚ INICIAL
	set_pieces_visible(false)

	# Iniciar variables internas del modo por defecto (SIN tocar visuales aún)
	current_game_type = GameType.TIC_TAC_TOE
	current_cols = TTT_COLS
	current_rows = TTT_ROWS
	current_win_len = TTT_WIN_LEN
	current_piece_size = PIECE_SIZE_TTT
	_update_cell_nodes_reference(grid_ttt)
	
	# --- CORRECCIÓN FINAL: Forzar ocultación explícita al final del ready ---
	grid_ttt.hide()
	grid_c4.hide()
	result_label.hide()
	# ----------------------------------------------------------------------
func _process(_delta):
	if multiplayer.has_multiplayer_peer() and is_game_active:
		var mouse_pos = get_viewport().get_mouse_position()
		rpc("send_cursor_position", mouse_pos)

# --- LÓGICA DE SELECCIÓN DE JUEGO ---

func _generate_connect4_grid():
	# Limpiar hijos existentes
	for child in grid_c4.get_children():
		child.queue_free()
	
	# Generar 42 slots (botones)
	var total_slots = C4_COLS * C4_ROWS
	for i in range(total_slots):
		var btn = Button.new()
		# Ajuste visual para el grid escalado
		btn.custom_minimum_size = Vector2(12, 12) 
		btn.name = str(i)
		grid_c4.add_child(btn)

func _on_game_mode_selected(index: int):
	var selected_id = option_button.get_item_id(index)
	
	# CASO 1: Offline (Menú principal sin red)
	if not multiplayer.has_multiplayer_peer():
		set_game_mode(selected_id)
		
	# CASO 2: Host (Servidor activo)
	elif multiplayer.is_server():
		# 1. Cambiamos la configuración del modo
		rpc("set_game_mode", selected_id)
		
		# 2. CORRECCIÓN: Solo sincronizamos arranque (active=true) si tenemos oponente.
		# Si get_peers().size() > 0 significa que hay clientes conectados.
		if multiplayer.get_peers().size() > 0:
			rpc("sync_game_state", board, pieces_left_X, pieces_left_O, player_o_net_id, current_game_type)
		
	# CASO 3: Cliente
	else:
		_sync_option_button_ui()
@rpc("any_peer", "call_local", "reliable")
func set_game_mode(mode_id: int):
	current_game_type = mode_id
	
	if current_game_type == GameType.TIC_TAC_TOE:
		current_cols = TTT_COLS
		current_rows = TTT_ROWS
		current_win_len = TTT_WIN_LEN
		current_piece_size = PIECE_SIZE_TTT
		
		# CORRECCIÓN: Solo nos aseguramos de OCULTAR el que no toca.
		# No forzamos grid_ttt.show() aquí. Si el juego debe verse, 
		# sync_game_state lo mostrará.
		grid_c4.hide()
			
		_update_cell_nodes_reference(grid_ttt)
		
	elif current_game_type == GameType.CONNECT_4:
		current_cols = C4_COLS
		current_rows = C4_ROWS
		current_win_len = C4_WIN_LEN
		current_piece_size = PIECE_SIZE_C4
		
		# CORRECCIÓN: Solo ocultar el contrario.
		grid_ttt.hide()
			
		_update_cell_nodes_reference(grid_c4)
	
	_sync_option_button_ui()
	
	# Resetear lógica interna si la red está activa
	if multiplayer.has_multiplayer_peer():
		reset_game(multiplayer.has_multiplayer_peer())
	# Resetear lógica interna
	if multiplayer.has_multiplayer_peer():
		reset_game(multiplayer.has_multiplayer_peer())
func _sync_option_button_ui():
	for i in range(option_button.item_count):
		if option_button.get_item_id(i) == current_game_type:
			if option_button.selected != i:
				option_button.select(i)
			break

func _update_cell_nodes_reference(active_grid: GridContainer):
	cell_nodes.clear()
	for child in active_grid.get_children():
		cell_nodes.append(child)

# --- CREACIÓN DE PIEZAS (SPAWN) ---

func _on_add_piece_pressed(symbol: int):
	if not is_game_active: return
	rpc_id(1, "spawn_new_piece", symbol)

@rpc("any_peer", "call_local")
func spawn_new_piece(symbol: int):
	if not multiplayer.is_server(): return
	
	var new_piece = piece_scene.instantiate()
	new_piece.player_symbol = symbol
	
	# IMPORTANTE: Asignar el tamaño actual al spawnear
	new_piece.piece_size = current_piece_size
	new_piece.scale = Vector2(1, 1)
	
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

# --- LÓGICA DE JUEGO Y MOVIMIENTO ---

func attempt_place_piece(new_index: int, piece_path: String, target_pos: Vector2, old_index: int = -1):
	if not multiplayer.has_multiplayer_peer():
		status_label.text = "Primero debes unirte a un juego."
		return
	
	# LÓGICA CONECTA 4: GRAVEDAD
	if current_game_type == GameType.CONNECT_4 and new_index != -1:
		new_index = _get_lowest_available_in_column(new_index)
		if new_index == -1:
			status_label.text = "Columna llena."
			var p = get_node(piece_path)
			if p: p.return_to_last_valid_pos()
			return
		
		# Actualizar target_pos visual al nuevo slot
		if new_index < cell_nodes.size():
			var target_cell = cell_nodes[new_index]
			target_pos = target_cell.get_global_rect().get_center()

	# Validación estándar
	if new_index != -1 and board[new_index] != EMPTY and new_index != old_index:
		status_label.text = "Casilla ocupada."
		var p = get_node(piece_path)
		if p: p.return_to_last_valid_pos()
		return

	rpc("place_piece", new_index, player_symbol, piece_path, target_pos, old_index)

func _get_lowest_available_in_column(index: int) -> int:
	var col = index % current_cols
	# Buscar desde abajo hacia arriba
	for r in range(current_rows - 1, -1, -1):
		var check_index = r * current_cols + col
		if board[check_index] == EMPTY:
			return check_index
	return -1 # Columna llena

@rpc("any_peer", "call_local")
func place_piece(new_index: int, symbol: int, piece_path: String, target_pos: Vector2, old_index: int):
	# Validar de nuevo (por seguridad en servidor)
	if new_index != -1 and board[new_index] != EMPTY and new_index != old_index:
		return
		
	if old_index != -1:
		board[old_index] = EMPTY
	
	if new_index != -1:
		board[new_index] = symbol
	
	var piece_node: RigidBody2D = get_node(piece_path)
	if is_instance_valid(piece_node):
		piece_node.current_cell_index = new_index
		piece_node.freeze = true
		piece_node.is_dragging = false
		piece_node.is_returning = false
		piece_node.linear_velocity = Vector2.ZERO
		piece_node.z_index = 0
		
		# ANIMACIÓN DE CAÍDA
		var final_pos = target_pos
		
		if current_game_type == GameType.CONNECT_4 and new_index != -1:
			var start_y = grid_c4.global_position.y - 100 
			var start_pos = Vector2(final_pos.x, start_y)
			piece_node.global_position = start_pos
			
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tween.tween_property(piece_node, "global_position", final_pos, 0.8)
		else:
			piece_node.global_position = final_pos
	
	update_board_ui()
	update_piece_counts_ui()
	
	if new_index != -1 and check_win(symbol):
		game_over(symbol)

# --- VERIFICACIÓN DE VICTORIA (GENÉRICA) ---
func check_win(symbol: int) -> bool:
	# Horizontal
	for r in range(current_rows):
		for c in range(current_cols - current_win_len + 1):
			if _check_line(symbol, r, c, 0, 1): return true
	# Vertical
	for r in range(current_rows - current_win_len + 1):
		for c in range(current_cols):
			if _check_line(symbol, r, c, 1, 0): return true
	# Diagonal \
	for r in range(current_rows - current_win_len + 1):
		for c in range(current_cols - current_win_len + 1):
			if _check_line(symbol, r, c, 1, 1): return true
	# Diagonal /
	for r in range(current_win_len - 1, current_rows):
		for c in range(current_cols - current_win_len + 1):
			if _check_line(symbol, r, c, -1, 1): return true
	return false

func _check_line(symbol: int, start_r: int, start_c: int, step_r: int, step_c: int) -> bool:
	for i in range(current_win_len):
		var r = start_r + step_r * i
		var c = start_c + step_c * i
		var idx = r * current_cols + c
		if board[idx] != symbol:
			return false
	return true

# --- FINALIZACIÓN Y REINICIO ---

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
	
	grid_ttt.hide()
	grid_c4.hide()
	set_pieces_visible(false)
	
	reset_timer.start()

func _on_ResetTimer_timeout():
	if multiplayer.is_server():
		# Verificar si el host cambió la opción visualmente mientras esperaba
		var selected_idx = option_button.selected
		if selected_idx != -1:
			var mode_from_ui = option_button.get_item_id(selected_idx)
			if mode_from_ui != current_game_type:
				set_game_mode(mode_from_ui)

		reset_game(true)
		rpc("sync_game_state", board, pieces_left_X, pieces_left_O, player_o_net_id, current_game_type)
	else:
		reset_game(false)

func reset_game(keep_peer: bool = false):
	# Redimensionar tablero según juego actual
	var total_cells = current_cols * current_rows
	board.resize(total_cells)
	board.fill(EMPTY)
	
	# Reiniciar contadores según juego
	var max_p = MAX_PIECES_TTT if current_game_type == GameType.TIC_TAC_TOE else MAX_PIECES_C4
	pieces_left_X = max_p
	pieces_left_O = max_p
	
	is_game_active = false
	
	update_board_ui()
	update_piece_counts_ui()
	
	result_label.hide()
	reset_timer.stop()
	
	# Limpiar piezas extra (spawned)
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		for child in piece_container.get_children():
			if child is RigidBody2D and not child.is_in_group("initial_pieces"):
				child.queue_free()
	
	reset_all_pieces_visuals()
	
	if not keep_peer and multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	
	if not keep_peer or not multiplayer.has_multiplayer_peer():
		player_o_net_id = PLAYER_O
		for peer_id in remote_cursors:
			if is_instance_valid(remote_cursors[peer_id]):
				remote_cursors[peer_id].queue_free()
		remote_cursors.clear()
		
		enable_network_buttons()
		grid_ttt.hide()
		grid_c4.hide()
		set_pieces_visible(false)
		status_label.text = "Selecciona juego y crea partida."
	elif multiplayer.is_server() and keep_peer:
		status_label.text = "Juego reiniciado. Esperando..."
		# Habilitar el botón de opción para el host durante el reinicio suave
		option_button.disabled = false

func reset_all_pieces_visuals():
	for piece in piece_container.get_children():
		if piece is RigidBody2D:
			piece.set_multiplayer_authority(1) # Temporal para mover
			if piece.is_in_group("initial_pieces"):
				piece.current_cell_index = -1
				piece.is_returning = false
				piece.freeze = true 
				piece.linear_velocity = Vector2.ZERO
				piece.rotation = 0
				piece.global_position = piece.original_position
				piece.z_index = 0
				
				# Restaurar tamaño correcto para las piezas iniciales
				if "piece_size" in piece:
					piece.piece_size = current_piece_size
					if piece.has_method("apply_visual_size"):
						piece.apply_visual_size()
						piece.update_symbol()

# --- FUNCIONES DE RED (HOST/JOIN) ---

func _on_HostButton_pressed():
	# 1. Asegurar que tenemos el modo correcto seleccionado en la UI
	var selected_idx = option_button.selected
	if selected_idx != -1:
		var desired_mode = option_button.get_item_id(selected_idx)
		if desired_mode != current_game_type:
			set_game_mode(desired_mode)
			
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(DEFAULT_PORT, MAX_PLAYERS) != OK:
		status_label.text = "Error al crear Host."
		return
		
	multiplayer.multiplayer_peer = peer
	player_symbol = PLAYER_X
	player_o_net_id = PLAYER_O
	status_label.text = "Host iniciado. Esperando jugador..."
	disable_network_buttons()
	# Forzar modo actual al iniciar servidor
	set_game_mode(current_game_type)

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
			update_piece_counts_ui()
			
			# Mostrar la grilla correcta
			if current_game_type == GameType.TIC_TAC_TOE:
				grid_ttt.show()
			else:
				grid_c4.show()

			set_pieces_visible(true)
			is_game_active = true
			player_o_net_id = id
			apply_piece_authorities_local()
			
			# Sincronizar estado completo con el cliente
			rpc("sync_game_state", board, pieces_left_X, pieces_left_O, player_o_net_id, current_game_type)

func _player_disconnected(id: int):
	status_label.text = "Oponente desconectado."
	is_game_active = false
	player_o_net_id = PLAYER_O
	if remote_cursors.has(id):
		if is_instance_valid(remote_cursors[id]):
			remote_cursors[id].queue_free()
		remote_cursors.erase(id)
	reset_game(false)

@rpc("any_peer", "call_local", "reliable") 
func sync_game_state(new_board: Array[int], new_pieces_X: int, new_pieces_O: int, new_player_o_net_id: int, game_mode: int): 
	# Si por error de sincronización el modo no coincide, lo forzamos
	if current_game_type != game_mode:
		set_game_mode(game_mode)

	board = new_board
	pieces_left_X = new_pieces_X
	pieces_left_O = new_pieces_O
	player_o_net_id = new_player_o_net_id
	
	update_board_ui()
	update_piece_counts_ui()
	disable_network_buttons()
	
	if current_game_type == GameType.TIC_TAC_TOE:
		grid_ttt.show()
		grid_c4.hide() # Asegurar que el otro se oculta
	else:
		grid_ttt.hide() # Asegurar que el otro se oculta
		grid_c4.show()
		
	# Esto vuelve a mostrar los botones de generar piezas
	set_pieces_visible(true)
	reset_all_pieces_visuals()
	
	# REACTIVACIÓN DEL JUEGO
	is_game_active = true
	apply_piece_authorities_local()
# --- UTILIDADES ---

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
		
	if is_instance_valid(remote_cursors[sender_id]):
		remote_cursors[sender_id].global_position = position

func apply_piece_authorities_local():
	if not multiplayer.has_multiplayer_peer(): return
	for piece in piece_container.get_children():
		if not piece is RigidBody2D: continue
		var target_id = PLAYER_X if piece.player_symbol == PLAYER_X else player_o_net_id
		piece.set_multiplayer_authority(target_id)

func update_board_ui():
	# Limpiar texto de botones si es necesario
	for i in range(cell_nodes.size()):
		var cell = cell_nodes[i]
		if cell is Button:
			cell.text = "" 

func update_piece_counts_ui():
	var symbol_name = "X" if player_symbol == PLAYER_X else "O"
	status_label.text = "Eres el jugador: " + symbol_name

func get_my_pieces_left() -> int:
	return pieces_left_X if player_symbol == PLAYER_X else pieces_left_O
	
func get_opponent_pieces_left() -> int:
	return pieces_left_O if player_symbol == PLAYER_X else pieces_left_X

func set_pieces_visible(is_visible: bool):
	for child in piece_container.get_children():
		if child is CanvasItem:
			child.visible = is_visible

func enable_network_buttons():
	host_button.show()
	join_button.show()
	ip_input.show()
	host_button.disabled = false
	join_button.disabled = false
	ip_input.editable = true
	option_button.disabled = false # Permitir cambiar juego

func disable_network_buttons():
	host_button.hide()
	join_button.hide()
	ip_input.hide()
	host_button.disabled = true
	join_button.disabled = true
	ip_input.editable = false

	if multiplayer.is_server():
		option_button.disabled = false
	else:
		option_button.disabled = true
