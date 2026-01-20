extends Node

signal steam_initialized
signal lobby_created_success(lobby_id)
signal lobby_created_fail
signal lobby_joined_success(lobby_id, owner_id)
signal lobby_join_fail
signal lobby_list_updated(lobbies)

var is_owned: bool = false
var steam_id: int = 0
var steam_username: String = ""

func _ready() -> void:
	_initialize_steam()
	
	# Conectar señales internas de Steam
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.join_requested.connect(_on_lobby_join_requested)

func _process(_delta: float) -> void:
	Steam.run_callbacks()

func _initialize_steam() -> void:
	var is_running: bool = Steam.steamInit()
	if not is_running:
		print("Error: Steam no está corriendo.")
		return
	
	is_owned = Steam.isSubscribed()
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	emit_signal("steam_initialized")

# --- Funciones Públicas para Main ---

func create_lobby(type, max_players):
	if Steam.isSteamRunning():
		Steam.createLobby(type, max_players)

func join_lobby(lobby_id: int):
	if Steam.isSteamRunning():
		Steam.joinLobby(lobby_id)

func refresh_lobby_list(game_version: String):
	if Steam.isSteamRunning():
		Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
		Steam.addRequestLobbyListStringFilter("game_version", game_version, Steam.LOBBY_COMPARISON_EQUAL)
		Steam.requestLobbyList()

func setup_lobby_data(lobby_id: int, data: Dictionary):
	# data espera claves como "name", "mode", "game_version"
	for key in data:
		Steam.setLobbyData(lobby_id, key, str(data[key]))

# --- Callbacks Internos ---

func _on_lobby_created(connect: int, lobby_id: int):
	if connect == 1:
		emit_signal("lobby_created_success", lobby_id)
	else:
		emit_signal("lobby_created_fail")

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int):
	if response == 1:
		var owner_id = Steam.getLobbyOwner(lobby_id)
		emit_signal("lobby_joined_success", lobby_id, owner_id)
	else:
		emit_signal("lobby_join_fail")

func _on_lobby_match_list(lobbies: Array):
	emit_signal("lobby_list_updated", lobbies)

func _on_lobby_join_requested(lobby_id: int, _friend_id: int):
	join_lobby(lobby_id)
