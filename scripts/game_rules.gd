class_name GameRules extends RefCounted

enum GameType { TIC_TAC_TOE = 1, CONNECT_4 = 2 }

const TTT_COLS = 3
const TTT_ROWS = 3
const TTT_WIN_LEN = 3

const C4_COLS = 7
const C4_ROWS = 6
const C4_WIN_LEN = 4

const EMPTY = 0

var board: Array[int] = []
var current_type = GameType.TIC_TAC_TOE
var rows = TTT_ROWS
var cols = TTT_COLS
var win_len = TTT_WIN_LEN

func setup_game(type: int):
	current_type = type
	if type == GameType.TIC_TAC_TOE:
		cols = TTT_COLS
		rows = TTT_ROWS
		win_len = TTT_WIN_LEN
	else:
		cols = C4_COLS
		rows = C4_ROWS
		win_len = C4_WIN_LEN
	
	board.resize(cols * rows)
	board.fill(EMPTY)

func reset_board():
	board.fill(EMPTY)

func is_valid_index(index: int) -> bool:
	return index >= 0 and index < board.size()

func is_cell_empty(index: int) -> bool:
	return is_valid_index(index) and board[index] == EMPTY

func set_piece(index: int, symbol: int):
	if is_valid_index(index):
		board[index] = symbol

func get_lowest_available_in_column(index: int) -> int:
	var col = index % cols
	for r in range(rows - 1, -1, -1):
		var check_index = r * cols + col
		if check_index < board.size() and board[check_index] == EMPTY:
			return check_index
	return -1

func check_win(symbol: int) -> bool:
	for r in range(rows):
		for c in range(cols - win_len + 1):
			if _check_line(symbol, r, c, 0, 1): return true
	for r in range(rows - win_len + 1):
		for c in range(cols):
			if _check_line(symbol, r, c, 1, 0): return true
	for r in range(rows - win_len + 1):
		for c in range(cols - win_len + 1):
			if _check_line(symbol, r, c, 1, 1): return true
	for r in range(win_len - 1, rows):
		for c in range(cols - win_len + 1):
			if _check_line(symbol, r, c, -1, 1): return true
	return false

func _check_line(symbol: int, start_r: int, start_c: int, step_r: int, step_c: int) -> bool:
	for i in range(win_len):
		var r = start_r + step_r * i
		var c = start_c + step_c * i
		var idx = r * cols + c
		if idx >= board.size() or board[idx] != symbol:
			return false
	return true
