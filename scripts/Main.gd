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

const MAX_PLAYERS = 2 
const MAX_PIECES_TTT = 5
const MAX_PIECES_C4 = 21 

const CURSOR_SCENE_PATH = "res://scenes/cursor.tscn"
const PIECE_SCENE_PATH = "res://scenes/piece.tscn"
const GAME_VERSION_ID = "tres_en_raya_yisus_v1"
const DEFAULT_PORT = 7777

var board: Array[int] = []
var player_symbol: int
var pieces_left_X: int = MAX_PIECES_TTT
var pieces_left_O: int = MAX_PIECES_TTT
var player_o_net_id: int = PLAYER_O
var is_game_active: bool = false
var remote_cursors: Dictionary = {}
var cursor_scene: PackedScene
var piece_scene: PackedScene
var cell_nodes: Array = [] 
var peer

var steam_lobby_id: int = 0

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

@onready var lobby_node: Control = $Lobby
@onready var start_game_button: Button = $Lobby/Button
@onready var slots_team1 = [$"Lobby/GridContainer/Slot1T1", $"Lobby/GridContainer/Slot2T1"]
@onready var slots_team2 = [$"Lobby/GridContainer/Slot1T2", $"Lobby/GridContainer/Slot2T2"]
@onready var colors_team1 = [$Lobby/ColorT11, $"Lobby/Color T12"]
@onready var colors_team2 = [$Lobby/ColorT21, $Lobby/ColorT22]

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var lobby_list_container: VBoxContainer = $ScrollContainer/LobbyContainer
@onready var refresh_button: Button = $RefreshButton

@onready var steam_check: CheckBox = $SteamCheckBox 

var lobby_players: Dictionary = {}
var my_selected_color: Color = Color.WHITE

func _ready():
	peer = SteamMultiplayerPeer.new()

	if ResourceLoader.exists(CURSOR_SCENE_PATH):
		cursor_scene = load(CURSOR_SCENE_PATH)
	if ResourceLoader.exists(PIECE_SCENE_PATH):
		piece_scene = load(PIECE_SCENE_PATH)
	
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_lobby_join_requested)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	
	btn_add_x.pressed.connect(_on_add_piece_pressed.bind(PLAYER_X))
	btn_add_o.pressed.connect(_on_add_piece_pressed.bind(PLAYER_O))
	option_button.item_selected.connect(_on_game_mode_selected)
	start_game_button.pressed.connect(_on_start_game_pressed)
	
	if refresh_button:
		refresh_button.pressed.connect(refresh_lobby_list)
	
	if steam_check:
		steam_check.toggled.connect(_on_steam_check_toggled)
		_on_steam_check_toggled(steam_check.button_pressed)
	
	_generate_connect4_grid()
	
	for child in piece_container.get_children():
		if child is RigidBody2D:
			child.add_to_group("initial_pieces")
			if "original_position" in child:
				child.original_position = child.global_position

	set_pieces_visible(false)

	current_game_type = GameType.TIC_TAC_TOE
	current_cols = TTT_COLS
	current_rows = TTT_ROWS
	current_win_len = TTT_WIN_LEN
	current_piece_size = PIECE_SIZE_TTT
	_update_cell_nodes_reference(grid_ttt)
	
	grid_ttt.hide()
	grid_c4.hide()
	result_label.hide()
	lobby_node.hide()
	
	_set_menu_visibility(true)
	
	for i in range(slots_team1.size()):
		slots_team1[i].pressed.connect(_on_slot_pressed.bind(1, i))
	for i in range(slots_team2.size()):
		slots_team2[i].pressed.connect(_on_slot_pressed.bind(2, i))
		
	for i in range(colors_team1.size()):
		colors_team1[i].gui_input.connect(_on_color_input.bind(colors_team1[i], 1))
	for i in range(colors_team2.size()):
		colors_team2[i].gui_input.connect(_on_color_input.bind(colors_team2[i], 2))

func _process(_delta):
	Steam.run_callbacks() 
	
	if multiplayer.has_multiplayer_peer():
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			var mouse_pos = get_viewport().get_mouse_position()
			rpc("send_cursor_info", mouse_pos, my_selected_color)


func get_player_name() -> String:
	if steam_check and steam_check.button_pressed and Steam.isSteamRunning():
		return Steam.getPersonaName()
	else:
		return "Jugador_" + str(multiplayer.get_unique_id())

func _on_steam_check_toggled(is_steam: bool):
	if is_steam:
		ip_input.placeholder_text = "ID del Lobby (Copia/Pega)"
		if refresh_button: refresh_button.disabled = false
	else:
		ip_input.placeholder_text = "IP del Host (ej: 127.0.0.1)"
		if refresh_button: refresh_button.disabled = true


func _set_menu_visibility(is_visible: bool):
	if scroll_container: scroll_container.visible = is_visible
	if refresh_button: refresh_button.visible = is_visible
	if host_button: host_button.visible = is_visible
	if join_button: join_button.visible = is_visible
	if ip_input: ip_input.visible = is_visible
	if steam_check: steam_check.visible = is_visible
	
	if not is_visible and lobby_list_container:
		for child in lobby_list_container.get_children():
			child.queue_free()

func _on_HostButton_pressed():
	if steam_check and steam_check.button_pressed:
		if not Steam.isSteamRunning():
			status_label.text = "Error: Steam no está corriendo."
			return

		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_PLAYERS)
		status_label.text = "Creando Lobby Steam..."
		host_button.disabled = true
		join_button.disabled = true
	else:
		peer = ENetMultiplayerPeer.new()
		var error = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
		
		if error == OK:
			multiplayer.set_multiplayer_peer(peer)
			status_label.text = "Servidor IP iniciado."
			steam_lobby_id = 0 
			
			_set_menu_visibility(false)
			show_lobby(true) 
		else:
			status_label.text = "Error al crear servidor IP."

func _on_JoinButton_pressed():
	var input_str = ip_input.text.strip_edges()
	
	if steam_check and steam_check.button_pressed:
		if input_str.is_empty() or not input_str.is_valid_int():
			status_label.text = "ID inválido."
			return

		var lobby_id = int(input_str)
		status_label.text = "Uniendo a Steam..."
		Steam.joinLobby(lobby_id)
	else:
		status_label.text = "Conectando a IP..."
		peer = ENetMultiplayerPeer.new()
		var target_ip = input_str if input_str.length() > 0 else "127.0.0.1"
		var error = peer.create_client(target_ip, DEFAULT_PORT)
		
		if error == OK:
			multiplayer.set_multiplayer_peer(peer)
			_set_menu_visibility(false)
		else:
			status_label.text = "Error al conectar."

func refresh_lobby_list():
	if steam_check and not steam_check.button_pressed: return
	
	status_label.text = "Buscando partidas..."
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListStringFilter("game_version", GAME_VERSION_ID, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()
	
func _on_lobby_match_list(lobbies: Array):
	for child in lobby_list_container.get_children():
		child.queue_free()
	
	if lobbies.size() == 0:
		status_label.text = "No se encontraron partidas."
		return
		
	status_label.text = "Partidas encontradas: " + str(lobbies.size())
	
	for lobby_id in lobbies:
		var lobby_name = Steam.getLobbyData(lobby_id, "name")
		var mode = Steam.getLobbyData(lobby_id, "mode")
		var num_members = Steam.getNumLobbyMembers(lobby_id)
		
		if lobby_name == "":
			lobby_name = "Lobby " + str(lobby_id)
		
		var btn = Button.new()
		var mode_txt = " (3 en Raya)" if mode == str(GameType.TIC_TAC_TOE) else " (Conecta 4)"
		btn.text = lobby_name + mode_txt + " [" + str(num_members) + "/" + str(MAX_PLAYERS) + "]"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 40) 
		
		btn.pressed.connect(_on_lobby_list_button_pressed.bind(lobby_id))
		
		lobby_list_container.add_child(btn)

func _on_lobby_list_button_pressed(lobby_id: int):
	status_label.text = "Uniéndose a la sala..."
	host_button.disabled = true
	join_button.disabled = true 
	Steam.joinLobby(lobby_id)

func _on_lobby_created(connect: int, lobby_id: int):
	if connect == 1:
		steam_lobby_id = lobby_id 
		print("Lobby de Steam creado: ID " + str(lobby_id))
		
		var name_lobby = "Partida de " + Steam.getPersonaName()
		Steam.setLobbyData(lobby_id, "name", name_lobby)
		
		Steam.setLobbyData(lobby_id, "mode", str(current_game_type))
		
		Steam.setLobbyData(lobby_id, "game_version", GAME_VERSION_ID)
		
		DisplayServer.clipboard_set(str(lobby_id))
		
		peer = SteamMultiplayerPeer.new() 
		var error = peer.create_host(0)
		
		if error == OK:
			multiplayer.set_multiplayer_peer(peer)
			status_label.text = "Lobby ID: " + str(lobby_id)
			
			_set_menu_visibility(false)
			show_lobby(true) 
			
			Steam.allowP2PPacketRelay(true)
		else:
			status_label.text = "Fallo al crear Host"
			host_button.disabled = false
			print("Error socket: " + str(error))
	else:
		status_label.text = "Error de Steam al crear Lobby"
		host_button.disabled = false

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int):
	if response == 1:
		var id_owner = Steam.getLobbyOwner(lobby_id)
		var my_steam_id = Steam.getSteamID()
		
		if id_owner == my_steam_id:
			return 
		
		status_label.text = "Conectando al Host..."
		
		_set_menu_visibility(false)
		
		peer = SteamMultiplayerPeer.new() 
		peer.create_client(id_owner, 0)
		multiplayer.set_multiplayer_peer(peer)
	else:
		status_label.text = "Fallo al unirse."
		host_button.disabled = false
		join_button.disabled = false

func _on_lobby_join_requested(lobby_id: int, _friend_id: int):
	Steam.joinLobby(lobby_id)


func _generate_connect4_grid():
	for child in grid_c4.get_children():
		child.queue_free()
	var total_slots = C4_COLS * C4_ROWS
	for i in range(total_slots):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(12, 12) 
		btn.name = str(i)
		grid_c4.add_child(btn)

func _on_game_mode_selected(index: int):
	var selected_id = option_button.get_item_id(index)
	var was_active = is_game_active 
	
	if steam_lobby_id == 0 and not multiplayer.has_multiplayer_peer():
		set_game_mode(selected_id)
	elif multiplayer.is_server():
		rpc("set_game_mode", selected_id)
		if was_active:
			rpc("return_to_lobby")
	else:
		_sync_option_button_ui()

@rpc("any_peer", "call_local", "reliable")
func set_game_mode(mode_id: int):
	current_game_type = mode_id
	
	if multiplayer.is_server() and steam_lobby_id != 0:
		Steam.setLobbyData(steam_lobby_id, "mode", str(current_game_type))
	
	if current_game_type == GameType.TIC_TAC_TOE:
		current_cols = TTT_COLS
		current_rows = TTT_ROWS
		current_win_len = TTT_WIN_LEN
		current_piece_size = PIECE_SIZE_TTT
		if is_game_active:
			grid_c4.hide()
			grid_ttt.show()
		_update_cell_nodes_reference(grid_ttt)
		
	elif current_game_type == GameType.CONNECT_4:
		current_cols = C4_COLS
		current_rows = C4_ROWS
		current_win_len = C4_WIN_LEN
		current_piece_size = PIECE_SIZE_C4
		if is_game_active:
			grid_ttt.hide()
			grid_c4.show()
		_update_cell_nodes_reference(grid_c4)
	
	_sync_option_button_ui()
	
	if multiplayer.has_multiplayer_peer():
		reset_game(true, not is_game_active)
	else:
		lobby_node.hide()
		grid_ttt.hide()
		grid_c4.hide()
		
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

func _on_add_piece_pressed(symbol: int):
	if not is_game_active: return
	rpc_id(1, "spawn_new_piece", symbol)

@rpc("any_peer", "call_local")
func spawn_new_piece(symbol: int):
	if not multiplayer.is_server(): return
	var new_piece = piece_scene.instantiate()
	new_piece.player_symbol = symbol
	new_piece.piece_size = current_piece_size
	new_piece.scale = Vector2(1, 1)
	
	var spawn_pos = Vector2.ZERO
	if symbol == PLAYER_X: spawn_pos = spawn_x_pos.position
	else: spawn_pos = spawn_o_pos.position
	spawn_pos += Vector2(randf_range(-10, 10), randf_range(-10, 10))
	
	new_piece.position = spawn_pos
	new_piece.original_position = spawn_pos
	piece_container.add_child(new_piece, true)
	new_piece.set_multiplayer_authority(1)

func attempt_place_piece(new_index: int, piece_path: String, target_pos: Vector2, old_index: int = -1):
	if not multiplayer.has_multiplayer_peer():
		status_label.text = "Primero debes unirte a un juego."
		return
	if board.is_empty() or new_index >= board.size(): return

	if current_game_type == GameType.CONNECT_4 and new_index != -1:
		new_index = _get_lowest_available_in_column(new_index)
		if new_index == -1:
			status_label.text = "Columna llena."
			var p = get_node(piece_path)
			if p: p.return_to_last_valid_pos()
			return
		if new_index < cell_nodes.size():
			var target_cell = cell_nodes[new_index]
			target_pos = target_cell.get_global_rect().get_center()

	if new_index != -1 and board[new_index] != EMPTY and new_index != old_index:
		status_label.text = "Casilla ocupada."
		var p = get_node(piece_path)
		if p: p.return_to_last_valid_pos()
		return

	rpc("place_piece", new_index, player_symbol, piece_path, target_pos, old_index)

func _get_lowest_available_in_column(index: int) -> int:
	var col = index % current_cols
	for r in range(current_rows - 1, -1, -1):
		var check_index = r * current_cols + col
		if check_index < board.size() and board[check_index] == EMPTY:
			return check_index
	return -1 

@rpc("any_peer", "call_local")
func place_piece(new_index: int, symbol: int, piece_path: String, target_pos: Vector2, old_index: int):
	if board.is_empty(): return
	
	if new_index != -1:
		if new_index < 0 or new_index >= board.size(): return
		if board[new_index] != EMPTY and new_index != old_index: return
		
	if old_index != -1:
		if old_index >= 0 and old_index < board.size():
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

func check_win(symbol: int) -> bool:
	for r in range(current_rows):
		for c in range(current_cols - current_win_len + 1):
			if _check_line(symbol, r, c, 0, 1): return true
	for r in range(current_rows - current_win_len + 1):
		for c in range(current_cols):
			if _check_line(symbol, r, c, 1, 0): return true
	for r in range(current_rows - current_win_len + 1):
		for c in range(current_cols - current_win_len + 1):
			if _check_line(symbol, r, c, 1, 1): return true
	for r in range(current_win_len - 1, current_rows):
		for c in range(current_cols - current_win_len + 1):
			if _check_line(symbol, r, c, -1, 1): return true
	return false

func _check_line(symbol: int, start_r: int, start_c: int, step_r: int, step_c: int) -> bool:
	for i in range(current_win_len):
		var r = start_r + step_r * i
		var c = start_c + step_c * i
		var idx = r * current_cols + c
		if idx >= board.size(): return false
		if board[idx] != symbol:
			return false
	return true

func game_over(winning_symbol: int):
	await get_tree().create_timer(1.5).timeout
	var result_text = "¡EMPATE!"
	var result_color = Color.WHITE
	if winning_symbol != 0:
		var winner_name = ""
		if current_game_type == GameType.TIC_TAC_TOE:
			winner_name = "AZUL (X)" if winning_symbol == PLAYER_X else "ROJO (O)"
		else:
			winner_name = "AZUL" if winning_symbol == PLAYER_X else "ROJO"
		result_text = "¡GANA " + winner_name + "!"
		result_color = Color.BLUE if winning_symbol == PLAYER_X else Color.RED
	show_game_result(result_text, result_color)

func show_game_result(result_text: String, color: Color):
	status_label.text = ""
	result_label.text = result_text
	result_label.add_theme_color_override("font_color", color)
	result_label.show()
	reset_timer.start()

func _on_ResetTimer_timeout():
	if multiplayer.is_server():
		rpc("return_to_lobby")

@rpc("call_local", "reliable")
func return_to_lobby():
	reset_game(true, true)
	grid_ttt.hide()
	grid_c4.hide()
	set_pieces_visible(false)
	
	if multiplayer.is_server():
		status_label.text = "Partida finalizada. Configura la siguiente."
	else:
		status_label.text = "Esperando al anfitrión..."

func reset_game(keep_peer: bool = false, show_lobby_ui: bool = true):
	var total_cells = current_cols * current_rows
	board.resize(total_cells)
	board.fill(EMPTY)
	
	var max_p = MAX_PIECES_TTT if current_game_type == GameType.TIC_TAC_TOE else MAX_PIECES_C4
	pieces_left_X = max_p
	pieces_left_O = max_p
	is_game_active = false
	
	update_board_ui()
	update_piece_counts_ui()
	result_label.hide()
	reset_timer.stop()
	
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		for child in piece_container.get_children():
			if child is RigidBody2D and not child.is_in_group("initial_pieces"):
				child.queue_free()
	
	reset_all_pieces_visuals()
	
	if not keep_peer and multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
		if steam_lobby_id != 0:
			Steam.leaveLobby(steam_lobby_id)
			steam_lobby_id = 0
	
	if not keep_peer or not multiplayer.has_multiplayer_peer():
		player_o_net_id = PLAYER_O
		for peer_id in remote_cursors:
			if is_instance_valid(remote_cursors[peer_id]):
				remote_cursors[peer_id].queue_free()
		remote_cursors.clear()
		
		_set_menu_visibility(true) 
		host_button.disabled = false
		join_button.disabled = false
		
		grid_ttt.hide()
		grid_c4.hide()
		set_pieces_visible(false)
		lobby_node.hide()
		status_label.text = "Crea o busca una partida."
		if show_lobby_ui: lobby_node.show()
		else: lobby_node.hide()
	elif keep_peer:
		if show_lobby_ui: lobby_node.show()
		else: lobby_node.hide()

func reset_all_pieces_visuals():
	for piece in piece_container.get_children():
		if piece is RigidBody2D:
			piece.set_multiplayer_authority(1)
			if piece.is_in_group("initial_pieces"):
				piece.current_cell_index = -1
				piece.is_returning = false
				piece.freeze = true 
				piece.linear_velocity = Vector2.ZERO
				piece.rotation = 0
				piece.global_position = piece.original_position
				piece.z_index = 0
				if "piece_size" in piece:
					piece.piece_size = current_piece_size
					if piece.has_method("apply_visual_size"):
						piece.apply_visual_size()
						piece.update_symbol()

func _on_connected_to_server():
	status_label.text = "¡Conectado! Esperando al Host..."
	if not multiplayer.is_server():
		show_lobby(false)

func _connection_failed():
	status_label.text = "Error de conexión."
	is_game_active = false
	reset_game(false)

func _player_connected(id: int):
	if multiplayer.is_server():
		rpc_id(id, "update_lobby_state", lobby_players)
		if is_game_active:
			rpc_id(id, "sync_game_state", board, pieces_left_X, pieces_left_O, player_o_net_id, current_game_type)

func _player_disconnected(id: int):
	if lobby_players.has(id):
		lobby_players.erase(id)
		if multiplayer.is_server():
			rpc("update_lobby_state", lobby_players)
	if is_game_active:
		status_label.text = "Jugador desconectado."
	if remote_cursors.has(id):
		if is_instance_valid(remote_cursors[id]):
			remote_cursors[id].queue_free()
		remote_cursors.erase(id)

@rpc("any_peer", "call_local", "reliable") 
func sync_game_state(new_board: Array[int], new_pieces_X: int, new_pieces_O: int, new_player_o_net_id: int, game_mode: int): 
	set_game_mode(game_mode)
	board = new_board
	pieces_left_X = new_pieces_X
	pieces_left_O = new_pieces_O
	player_o_net_id = new_player_o_net_id
	
	update_board_ui()
	update_piece_counts_ui()
	
	_set_menu_visibility(false) 
	
	if current_game_type == GameType.TIC_TAC_TOE:
		grid_ttt.show()
		grid_c4.hide()
	else:
		grid_ttt.hide()
		grid_c4.show()
		
	set_pieces_visible(true)
	reset_all_pieces_visuals()
	is_game_active = true
	lobby_node.hide()

@rpc("any_peer", "unreliable")
func send_cursor_info(position: Vector2, color: Color):
	if not cursor_scene: return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == multiplayer.get_unique_id(): return 
	
	if not remote_cursors.has(sender_id):
		var cursor_node = cursor_scene.instantiate()
		add_child(cursor_node)
		remote_cursors[sender_id] = cursor_node
		
	if is_instance_valid(remote_cursors[sender_id]):
		remote_cursors[sender_id].global_position = position
		var p_name = ""
		if lobby_players.has(sender_id):
			p_name = lobby_players[sender_id].name
		remote_cursors[sender_id].set_cursor_info(p_name, color)

func update_board_ui():
	for i in range(cell_nodes.size()):
		var cell = cell_nodes[i]
		if cell is Button:
			cell.text = "" 

func update_piece_counts_ui():
	var p1_player = "X"
	var p2_player = "O"
	var p1_piece = "X"
	var p2_piece = "O"
	var my_text = "Espectador"
	if player_symbol == PLAYER_X: my_text = p1_player
	elif player_symbol == PLAYER_O: my_text = p2_player
	
	status_label.text = "Eres: " + my_text
	if btn_add_x: btn_add_x.text = "Generar pieza " + p1_piece
	if btn_add_o: btn_add_o.text = "Generar pieza " + p2_piece

func set_pieces_visible(is_visible: bool):
	for child in piece_container.get_children():
		if child is CanvasItem: child.visible = is_visible

func show_lobby(is_host: bool):
	lobby_node.show()
	start_game_button.disabled = not is_host
	start_game_button.visible = is_host
	update_lobby_ui()


func _on_slot_pressed(team: int, slot_idx: int):
	var my_steam_name = get_player_name()
	rpc_id(1, "request_slot_selection", multiplayer.get_unique_id(), team, slot_idx, my_steam_name)

@rpc("any_peer", "call_local")
func request_slot_selection(requesting_id: int, team: int, slot_idx: int, player_name: String):
	if not multiplayer.is_server(): return
	
	for pid in lobby_players:
		var p_data = lobby_players[pid]
		if p_data.team == team and p_data.slot_idx == slot_idx:
			return 
	

	if steam_lobby_id == 0:
		var taken_numbers = []
		for pid in lobby_players:
			var p_name = lobby_players[pid]["name"]
			if p_name.begins_with("Jugador "):
				var num_str = p_name.trim_prefix("Jugador ")
				if num_str.is_valid_int():
					taken_numbers.append(int(num_str))
		
		var new_number = 1
		while new_number in taken_numbers:
			new_number += 1
			
		player_name = "Jugador " + str(new_number)
	
	lobby_players[requesting_id] = {
		"team": team,
		"slot_idx": slot_idx,
		"color": Color.WHITE,
		"name": player_name 
	}
	rpc("update_lobby_state", lobby_players)

func _on_color_input(event: InputEvent, panel: Panel, team_color: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var my_id = multiplayer.get_unique_id()
		if not lobby_players.has(my_id): return
		if lobby_players[my_id].team != team_color: return
		var style = panel.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			my_selected_color = style.bg_color
			rpc_id(1, "request_color_change", my_id, my_selected_color)

@rpc("any_peer", "call_local")
func request_color_change(id: int, new_color: Color):
	if not multiplayer.is_server(): return
	if lobby_players.has(id):
		lobby_players[id]["color"] = new_color
		rpc("update_lobby_state", lobby_players)

@rpc("authority", "call_local", "reliable")
func update_lobby_state(new_lobby_data: Dictionary):
	lobby_players = new_lobby_data
	update_lobby_ui()

func update_lobby_ui():
	var all_slots = []
	all_slots.append_array(slots_team1)
	all_slots.append_array(slots_team2)
	for btn in all_slots:
		btn.text = "Libre"
		btn.disabled = false
	
	var my_id = multiplayer.get_unique_id()
	var my_team = -1
	var my_current_color = Color.TRANSPARENT 
	
	for pid in lobby_players:
		var data = lobby_players[pid]
		var team = data.team
		var idx = data.slot_idx
		var p_name = data.name 
		
		if pid == my_id:
			my_team = team
			player_symbol = team
			if data.has("color"): my_current_color = data.color
		
		var target_btn = null
		if team == 1 and idx < slots_team1.size(): target_btn = slots_team1[idx]
		elif team == 2 and idx < slots_team2.size(): target_btn = slots_team2[idx]
			
		if target_btn:
			target_btn.text = p_name
			target_btn.disabled = true
	
	var update_visuals = func(panel_array, team_id):
		for p in panel_array:
			p.modulate.a = 1.0 if my_team == team_id else 0.3
			var sb = p.get_theme_stylebox("panel")
			if sb is StyleBoxFlat:
				sb.border_width_left = 0
				sb.border_width_top = 0
				sb.border_width_right = 0
				sb.border_width_bottom = 0
				if my_team == team_id and sb.bg_color.is_equal_approx(my_current_color):
					sb.border_width_left = 5
					sb.border_width_top = 5
					sb.border_width_right = 5
					sb.border_width_bottom = 5
					sb.border_color = Color.WHITE

	update_visuals.call(colors_team1, 1)
	update_visuals.call(colors_team2, 2)

func _on_start_game_pressed():
	rpc("sync_game_state", board, pieces_left_X, pieces_left_O, player_o_net_id, current_game_type)
	rpc("start_match_from_lobby")

@rpc("call_local", "reliable")
func start_match_from_lobby():
	lobby_node.hide()
	is_game_active = true
	update_piece_counts_ui()
	set_pieces_visible(true)
	if current_game_type == GameType.TIC_TAC_TOE:
		grid_ttt.show()
	else:
		grid_c4.show()
