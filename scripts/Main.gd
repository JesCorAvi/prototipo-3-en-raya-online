extends Node2D

# ==============================================================================
# --- CONSTANTES Y VARIABLES GLOBALES ---
# ==============================================================================

const BOARD_SIZE = 9
const PLAYER_X = 1
const PLAYER_O = 2
const EMPTY = 0

const DEFAULT_PORT = 10567 
const MAX_PLAYERS = 2      

var board: Array[int] = [] 
var current_player: int = PLAYER_X 
var game_active: bool = false 
var player_symbol: int 

# ==============================================================================
# --- REFERENCIAS DE NODO (@onready) ---
# ==============================================================================

@onready var grid_container: GridContainer = $GridContainer
@onready var status_label: Label = $StatusLabel
@onready var host_button: Button = $HostButton
@onready var join_button: Button = $JoinButton
@onready var ip_input: LineEdit = $IPAddress

@onready var result_label: Label = $ResultLabel
@onready var reset_timer: Timer = $ResetTimer   

# ==============================================================================
# --- FLUJO PRINCIPAL ---
# ==============================================================================

func _ready():
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	
	grid_container.hide()
	result_label.hide()
	reset_game()

# ==============================================================================
# --- MANEJO DE CONEXIÓN DE RED (HOST/CLIENTE) ---
# ==============================================================================

func _on_HostButton_pressed():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if error != OK:
		status_label.text = "Error al crear Host."
		return
		
	multiplayer.multiplayer_peer = peer
	player_symbol = PLAYER_X 
	status_label.text = "Host iniciado. Esperando jugador..."
	disable_network_buttons() 

func _on_JoinButton_pressed():
	var ip = ip_input.text if not ip_input.text.is_empty() else "127.0.0.1"
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, DEFAULT_PORT)
	if error != OK:
		status_label.text = "Error al crear Cliente."
		return

	multiplayer.multiplayer_peer = peer
	player_symbol = PLAYER_O 
	status_label.text = "Conectando..."
	disable_network_buttons() 

# ==============================================================================
# --- GENERACIÓN DE MENSAJES DE ESTADO ---
# ==============================================================================

func _get_turn_status_message(player: int) -> String:
	if not game_active:
		return ""
		
	if player == player_symbol:
		return "¡Tu turno!"
	else:
		return "Turno del contrincante"

# ==============================================================================
# --- SINCRONIZACIÓN DE ESTADO (RPC) ---
# ==============================================================================

func _player_connected(id: int):
	if multiplayer.is_server():
		if multiplayer.get_peers().size() == 1:
			
			game_active = true
			current_player = PLAYER_X
			var text = _get_turn_status_message(PLAYER_X) 
			status_label.text = text
			
			grid_container.show()

			rpc("sync_game_state", game_active, current_player, text)

@rpc("any_peer") 
func sync_game_state(new_game_active: bool, new_current_player: int, status_text: String):
	game_active = new_game_active
	current_player = new_current_player
	
	status_label.text = _get_turn_status_message(new_current_player)
	
	if game_active:
		disable_network_buttons()
		grid_container.show()

func _player_disconnected(id: int):
	if game_active:
		status_label.text = "¡El oponente se desconectó! Juego terminado."
		reset_game(false)

@rpc("any_peer") 
func update_status_message(message: String):
	status_label.text = message

# ==============================================================================
# --- LÓGICA DEL JUEGO (MOVIMIENTOS) ---
# ==============================================================================

func _on_CellButton_pressed(index: int):
	if not game_active:
		status_label.text = "El juego aún no ha comenzado o ya terminó."
		return
		
	if board[index] == EMPTY:
		rpc("register_move", index, player_symbol)
	else:
		status_label.text = "Casilla ocupada."

@rpc("any_peer", "call_local")
func register_move(index: int, symbol: int):
	if not game_active or board[index] != EMPTY:
		return
		
	if current_player != symbol:
		var caller_id = multiplayer.get_remote_sender_id() 
		var error_message = "¡No es tu turno! Espera a " + ("O" if current_player == PLAYER_O else "X")
		
		if caller_id > 1:
			rpc_id(caller_id, "update_status_message", error_message)
		else:
			status_label.text = error_message
			
		return
		
	board[index] = symbol
	var button: Button = grid_container.get_child(index)
	button.text = "X" if symbol == PLAYER_X else "O"
	button.disabled = true 
	
	if check_win(symbol):
		game_active = false
		var result_text: String
		var result_color: Color
		
		if symbol == player_symbol:
			result_text = "¡GANASTE!"
			result_color = Color.GREEN 
		else:
			result_text = "PERDISTE"
			result_color = Color.RED 

		status_label.text = "" 
		result_label.text = result_text
		result_label.add_theme_color_override("font_color", result_color)
		
		rpc("game_over", result_text)
	elif check_tie():
		game_active = false
		var result_text = "¡EMPATE!"
		
		status_label.text = "" 
		result_label.text = result_text
		result_label.remove_theme_color_override("font_color")
		
		rpc("game_over", result_text)
	else:
		current_player = PLAYER_O if current_player == PLAYER_X else PLAYER_X
		status_label.text = _get_turn_status_message(current_player)

@rpc("call_local")
func game_over(result_text: String):
	game_active = false
	
	result_label.show() 
	
	reset_timer.start() 

# ==============================================================================
# --- MANEJO DEL TEMPORIZADOR ---
# ==============================================================================

func _on_ResetTimer_timeout():
	reset_game(false)


# ==============================================================================
# --- LÓGICA DE JUEGO (GANAR/EMPATAR) ---
# ==============================================================================

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

func check_tie() -> bool:
	return not board.has(EMPTY)

# ==============================================================================
# --- CONTROL DE UI Y ESTADO ---
# ==============================================================================

func reset_game(keep_active: bool = false):
	board.resize(BOARD_SIZE)
	board.fill(EMPTY)
	current_player = PLAYER_X
	game_active = keep_active
	
	for i in range(BOARD_SIZE):
		var button: Button = grid_container.get_child(i)
		button.text = ""
		button.disabled = false
	
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null 
	
	result_label.hide()
	reset_timer.stop()  

	if not multiplayer.has_multiplayer_peer() or not game_active:
		enable_network_buttons()
		grid_container.hide() 
		status_label.text = "Presiona Crear Juego o Unirse para empezar."
	elif multiplayer.is_server() and not game_active:
		status_label.text = "Host listo. Esperando al oponente..."

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
