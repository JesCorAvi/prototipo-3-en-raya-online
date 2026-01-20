extends Node

enum GameType { TIC_TAC_TOE = 1, CONNECT_4 = 2 }
var board: Array[int] = []
var current_game_type = GameType.TIC_TAC_TOE

var cols = 3
var rows = 3
var win_len = 3

@rpc("any_peer", "call_local", "reliable")
func set_game_mode(mode_id: int):
	current_game_type = mode_id
	if mode_id == GameType.TIC_TAC_TOE:
		_setup_dims(3, 3, 3)
	else:
		_setup_dims(7, 6, 4)
	reset_board()

func _setup_dims(c, r, w):
	cols = c
	rows = r
	win_len = w

func reset_board():
	board.clear()
	board.resize(cols * rows)
	board.fill(0)

func check_win(symbol: int) -> bool:

	var directions = [[0, 1], [1, 0], [1, 1], [-1, 1]]
	for r in range(rows):
		for c in range(cols):
			for d in directions:
				if _check_line(symbol, r, c, d[0], d[1]):
					return true
	return false

func _check_line(symbol: int, start_r: int, start_c: int, step_r: int, step_c: int) -> bool:
	for i in range(win_len):
		var r = start_r + step_r * i
		var c = start_c + step_c * i
		if r < 0 or r >= rows or c < 0 or c >= cols: return false
		if board[r * cols + c] != symbol: return false
	return true
