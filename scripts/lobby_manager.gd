extends Node
class_name LobbyManager

var lobby_players: Dictionary = {}

func clear_players():
	lobby_players.clear()

func add_player(id: int, team: int, slot_idx: int, name: String) -> void:
	lobby_players[id] = {
		"team": team,
		"slot_idx": slot_idx,
		"color": Color.WHITE,
		"name": name
	}

func remove_player(id: int):
	if lobby_players.has(id):
		lobby_players.erase(id)

func get_player_data(id: int):
	return lobby_players.get(id)

func is_slot_taken(team: int, slot_idx: int) -> bool:
	for pid in lobby_players:
		var p_data = lobby_players[pid]
		if p_data.team == team and p_data.slot_idx == slot_idx:
			return true
	return false

func get_unique_player_name(base_name: String) -> String:
	# Si ya tenemos lógica de nombres Steam, esto sirve para fallbacks o IP directa
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
		
	return "Jugador " + str(new_number)

func update_player_color(id: int, new_color: Color):
	if lobby_players.has(id):
		lobby_players[id]["color"] = new_color

func update_lobby_data(new_data: Dictionary):
	lobby_players = new_data
