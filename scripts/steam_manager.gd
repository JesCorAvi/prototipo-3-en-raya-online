extends Node

# Señal opcional por si necesitas saber cuándo Steam está listo
signal steam_initialized

var is_owned: bool = false
var steam_id: int = 0
var steam_username: String = ""

func _ready() -> void:
	_initialize_steam()

func _process(_delta: float) -> void:
	# Importante: Procesa los callbacks de Steam en cada frame
	Steam.run_callbacks()

func _initialize_steam() -> void:
	# CORRECCIÓN: steamInit devuelve un bool ahora, no un Dictionary
	var is_running: bool = Steam.steamInit()
	
	print("¿Steam inicializado?: " + str(is_running))
	
	if not is_running:
		print("Error: Steam no se está ejecutando o el appid no es correcto.")
		return
	
	# Obtener datos del usuario actual
	is_owned = Steam.isSubscribed()
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	
	print("Usuario Steam: " + str(steam_username))
	print("ID Steam: " + str(steam_id))
	
	emit_signal("steam_initialized")
