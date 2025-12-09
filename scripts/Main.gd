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
const MAX_PLAYER_PIECES = 3 # Límite de piezas por jugador (3)

# El estado del tablero y el contador de piezas deben sincronizarse.
var board: Array[int] = [] 
var player_symbol: int 

var pieces_left_X: int = MAX_PLAYER_PIECES
var pieces_left_O: int = MAX_PLAYER_PIECES

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

var cell_nodes: Array = [] 

# ==============================================================================
# --- FLUJO PRINCIPAL ---
# ==============================================================================

func _ready():
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	# Manejar el fallo de conexión (TIMEOUT)
	multiplayer.connection_failed.connect(_connection_failed) 
	
	# Obtener las referencias a las celdas de la cuadrícula
	for i in range(BOARD_SIZE):
		cell_nodes.append(grid_container.get_child(i))

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

func _connection_failed():
	status_label.text = "Error: No se pudo conectar al servidor. Reintentar o crear Host."
	reset_game(false)

func _player_connected(id: int):
	if multiplayer.is_server():
		if multiplayer.get_peers().size() == 1:
			status_label.text = "¡Jugador O conectado! Juego en tiempo real."
			grid_container.show()
			# Sincronizar estado inicial
			rpc("sync_game_state", board, pieces_left_X, pieces_left_O)

@rpc("any_peer") 
func sync_game_state(new_board: Array[int], new_pieces_X: int, new_pieces_O: int):
	# Recibe el estado del juego desde el servidor
	board = new_board
	pieces_left_X = new_pieces_X
	pieces_left_O = new_pieces_O
	
	update_board_ui()
	update_piece_counts_ui()
	disable_network_buttons()
	grid_container.show()
	
func _player_disconnected(id: int):
	status_label.text = "¡El oponente se desconectó! Juego terminado."
	reset_game(false)

# ==============================================================================
# --- LÓGICA DEL JUEGO (MOVIMIENTOS EN TIEMPO REAL) ---
# ==============================================================================

# Esta función DEBE ser llamada desde la lógica de Drag-and-Drop 
# cuando una pieza del jugador local es soltada en la celda 'index'.
func attempt_place_piece(index: int):
	var my_pieces_left = get_my_pieces_left()
	
	if not multiplayer.has_multiplayer_peer():
		status_label.text = "Primero debes unirte a un juego."
		return
		
	if board[index] != EMPTY:
		status_label.text = "Casilla ocupada."
		return

	if my_pieces_left <= 0:
		status_label.text = "¡Ya has colocado tus 3 piezas! Espera el resultado."
		return

	# Si es válido, enviamos la acción a todos (servidor y clientes)
	# Usamos @rpc("any_peer", "call_local") para que todos procesen el movimiento.
	rpc("place_piece", index, player_symbol)

@rpc("any_peer", "call_local")
func place_piece(index: int, symbol: int):
	# Verificación estricta contra movimientos inválidos
	var pieces_ref: int = pieces_left_X if symbol == PLAYER_X else pieces_left_O
	
	if board[index] != EMPTY or pieces_ref <= 0:
		# Movimiento inválido o pieza agotada. Ignorar.
		return
		
	# 1. Actualizar el estado del juego
	board[index] = symbol
	
	# 2. Actualizar el contador de piezas
	if symbol == PLAYER_X:
		pieces_left_X -= 1
	elif symbol == PLAYER_O:
		pieces_left_O -= 1
	
	# 3. Actualizar la UI
	update_board_ui()
	update_piece_counts_ui()
	
	# 4. Comprobar victoria/fin de juego
	if check_win(symbol):
		game_over(symbol)
	elif pieces_left_X == 0 and pieces_left_O == 0:
		game_over(0) # Empate (ambos agotaron sus piezas)

# ==============================================================================
# --- LÓGICA DE JUEGO (GANAR/FIN) ---
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

func game_over(winning_symbol: int):
	var result_text: String
	var result_color: Color
	
	if winning_symbol == 0:
		result_text = "¡EMPATE!"
		result_color = Color.WHITE
	else:
		var winner_name = "X" if winning_symbol == PLAYER_X else "O"
		result_text = "¡GANA " + winner_name + "!"
		
		# Determinar color para el jugador local
		result_color = Color.RED 
		if winning_symbol == player_symbol:
			result_color = Color.GREEN 

	# Llamada directa a la función local. La lógica de sincronización está en place_piece.
	show_game_result(result_text, result_color)

# Función local para mostrar el resultado final
func show_game_result(result_text: String, color: Color):
	# Mostrar el resultado final a todos
	status_label.text = "" 
	result_label.text = result_text
	result_label.add_theme_color_override("font_color", color)
	result_label.show() 
	
	reset_timer.start() # Iniciar el temporizador para reiniciar

# ==============================================================================
# --- MANEJO DEL TEMPORIZADOR Y REINICIO ---
# ==============================================================================

func _on_ResetTimer_timeout():
	if multiplayer.is_server():
		# El host reinicia y sincroniza el nuevo estado con todos
		reset_game(true)
		rpc("sync_game_state", board, pieces_left_X, pieces_left_O)
	else:
		# Los clientes esperan a la sincronización del host
		reset_game(false)


# ==============================================================================
# --- CONTROL DE UI Y ESTADO ---
# ==============================================================================

func reset_game(keep_peer: bool = false):
	# Reinicia el tablero y los contadores
	board.resize(BOARD_SIZE)
	board.fill(EMPTY)
	pieces_left_X = MAX_PLAYER_PIECES
	pieces_left_O = MAX_PLAYER_PIECES
	
	update_board_ui()
	update_piece_counts_ui()
	
	result_label.hide()
	reset_timer.stop()
	
	if not keep_peer and multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null 

	if not keep_peer or not multiplayer.has_multiplayer_peer():
		enable_network_buttons()
		grid_container.hide() 
		status_label.text = "Presiona Crear Juego o Unirse para empezar."
	elif multiplayer.is_server() and keep_peer:
		status_label.text = "Juego reiniciado. Esperando al oponente (x" + str(get_my_pieces_left()) + ")"

func update_board_ui():
	# Actualiza la representación visual del tablero
	for i in range(BOARD_SIZE):
		var cell = cell_nodes[i] 
		var symbol = board[i]
		
		# NOTA: Si cambiaste los botones por otros nodos (ej. Panel o ColorRect), 
		# deberás adaptar la forma de mostrar el símbolo aquí.
		if cell is Button: 
			var button_cell: Button = cell
			if symbol == PLAYER_X:
				button_cell.text = "X"
			elif symbol == PLAYER_O:
				button_cell.text = "O"
			else:
				button_cell.text = ""

func update_piece_counts_ui():
	# Esta función actualiza el contador de piezas disponibles
	var my_pieces = get_my_pieces_left()
	var opponent_pieces = get_opponent_pieces_left()
	
	status_label.text = "Te quedan " + str(my_pieces) + " piezas. Oponente: " + str(opponent_pieces)

func get_my_pieces_left() -> int:
	if player_symbol == PLAYER_X:
		return pieces_left_X
	elif player_symbol == PLAYER_O:
		return pieces_left_O
	return 0
	
func get_opponent_pieces_left() -> int:
	if player_symbol == PLAYER_X:
		return pieces_left_O
	elif player_symbol == PLAYER_O:
		return pieces_left_X
	return 0

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
