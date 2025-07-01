extends Node2D
class_name Game

# ───────────────────── Constants & enums ─────────────────────
const TILE_SIZE := Global.TILE_SIZE
enum State { RUNNING, ENDED, PROMOTING }

# ──────────────── Engine-node dependencies (on-ready) ─────────
@onready var stockfish     : Node          = $StockfishBot
@onready var board_node    : Node2D        = $Board
@onready var game_over_ui  : AcceptDialog  = $GameOver
@onready var Util_Func  : Node  = $Util_Functions



# ─────────────────────── Pure-data members ────────────────────
var board          : Array               # 8×8 Piece | null matrix
var round_num      : int      = 1
var turn           : String   = "white"
var state                       = State.RUNNING

var selected_piece : Piece
var moves          : Dictionary = {}
var from_pos       : Vector2i

# ───────────── Cached global flags (one lookup only) ──────────
var is_vs_bot      := Global.vs_bot
var is_vs_human    := Global.vs_human
var player_color   := Global.player_color
var is_host        := Global.host
var is_guest       := Global.guest


# ╭───────────────────────── LIFECYCLE ─────────────────────────╮
func _ready() -> void:
	_init_board()
	_first_move_if_needed()


func _unhandled_input(event: InputEvent) -> void:
	if state != State.RUNNING or not Util_Func._is_human_turn(turn):
		return

	if event.is_action_pressed("left_click"):
		var pos := _get_tile_pos()
		if moves.has(pos):
			if is_vs_bot:
				_make_move_vs_bot(pos)
			elif is_vs_human:
				_make_move_pvp(pos)
		else:
			_show_moves(pos)
		board_node.queue_redraw()

	elif event.is_action_pressed("ui_accept"):
		_flip_board()
# ╰─────────────────────────────────────────────────────────────╯



# ╭──────────────────────── HELPERS ────────────────────────────╮
func _init_board() -> void:
	var values = Create.create_board(Create.DEFAULT_BOARD)
	board      = values["board"]
	values["node"].name = "Pieces"
	add_child(values["node"])


func _first_move_if_needed() -> void:
	if is_vs_bot and player_color == "black":
		_prepare_black_bot_opening()
	elif is_vs_human and is_guest:
		_prepare_black_guest_opening()


func _prepare_black_bot_opening() -> void:
	_flip_board()
	await get_tree().process_frame
	_play_bot_turn()


func _prepare_black_guest_opening() -> void:
	player_color = "black"
	_flip_board()
	process_opponent_move(1)
# ╰─────────────────────────────────────────────────────────────╯



# ╭──────────────────────── TURN FLOW ──────────────────────────╮
func _do_local_move(pos: Vector2i) -> void:
	var move = moves[pos]
	moves.clear()
	_move_piece(pos, selected_piece)
	_process_turn(move, pos)


func _end_player_turn() -> void:
	turn = "black" if turn == "white" else "white"
	round_num += 1
	_check_game_end()


func _check_game_end() -> void:
	if no_legal_moves():
		state = State.ENDED
		var msg := "Stalemate!"
		if _is_in_check():
			msg = "%s is Checkmated!" % turn.capitalize()
		_game_over_dialog(msg)
	elif _is_in_check():
		print("Check!")


func _play_bot_turn() -> void:
	if state != State.RUNNING:
		return
	await get_tree().process_frame
	var bot_move = await stockfish.send_info_to_sf(board, round_num)
	if bot_move != "":
		_process_command(bot_move)
	turn = player_color
	round_num += 1
	_check_game_end()
# ╰─────────────────────────────────────────────────────────────╯



# ╭────────────────────── PUBLIC MOVES ─────────────────────────╮
func _make_move_vs_bot(pos: Vector2i) -> void:
	_do_local_move(pos)
	_end_player_turn()
	_play_bot_turn()


func _make_move_pvp(pos: Vector2i) -> void:
	_do_local_move(pos)
	_end_player_turn()
	MultiplayerManager.send_move_to_firebase(from_pos, pos, round_num)
	await process_opponent_move(round_num)
# ╰─────────────────────────────────────────────────────────────╯



# ╭────────────────────── BOARD UTILITIES ──────────────────────╮
func _flip_board() -> void:
	rotate(PI)
	for child in $Pieces.get_children():
		child.flip_v = not child.flip_v
		child.flip_h = child.flip_v
	var movement = Vector2.ONE * TILE_SIZE * 8
	self.position += -movement if self.position else movement


func _get_tile_pos() -> Vector2i:
	var mouse_pos = get_local_mouse_position()
	var pos = (mouse_pos / TILE_SIZE).floor()
	return pos.clamp(Vector2i.ZERO, Vector2i(7, 7))


func _show_moves(pos: Vector2i) -> void:
	if !board[pos.y][pos.x]:
		return
	var piece : Piece = board[pos.y][pos.x]
	if piece.team != turn:
		return

	if selected_piece == piece:
		moves.clear()
		selected_piece = null
		return

	moves = _get_legal_moves(piece)
	selected_piece = piece
# ╰─────────────────────────────────────────────────────────────╯



# ╭──────────────────── GAME-LOGIC CORE ────────────────────────╮
func _get_legal_moves(piece: Piece) -> Dictionary:
	var piece_moves = piece.get_moves(board)
	var original_pos := piece.pos

	for move in piece_moves.keys():
		var take_piece : Piece = null
		if piece_moves[move].type == Moves.CAPTURE:
			take_piece = piece_moves[move].take_piece
			board[take_piece.pos.y][take_piece.pos.x] = null

		board[piece.pos.y][piece.pos.x] = null
		board[move.y][move.x] = piece
		piece.pos = move

		if _is_in_check():
			piece_moves.erase(move)

		# reset
		piece.pos = original_pos
		board[move.y][move.x] = null
		board[piece.pos.y][piece.pos.x] = piece
		if take_piece:
			board[take_piece.pos.y][take_piece.pos.x] = take_piece

	return piece_moves


func _is_in_check() -> bool:
	for row in board:
		for piece in row:
			if !piece or piece.team == turn:
				continue
			for move in piece.get_moves(board).values():
				if move.type == Moves.CAPTURE and move.take_piece.piece_id == Piece.KING:
					return true
	return false


func no_legal_moves() -> bool:
	for row in board:
		for piece in row:
			if piece and piece.team == turn and _get_legal_moves(piece).size() > 0:
				return false
	return true
# ╰─────────────────────────────────────────────────────────────╯



# ╭──────────────────── PIECE MANIPULATION ─────────────────────╮
func _move_piece(pos: Vector2i, piece: Piece) -> void:
	from_pos = piece.pos
	board[piece.pos.y][piece.pos.x] = null
	board[pos.y][pos.x] = piece
	piece.last_move_round = round_num
	piece.pos = pos
	piece.move_animation(pos)
# ╰─────────────────────────────────────────────────────────────╯



# ╭──────────────────────── TURN-SIDE FX ───────────────────────╮
func _process_turn(move: Dictionary, pos: Vector2i) -> void:
	if move.type == Moves.CAPTURE:
		var t := get_tree().create_timer(Piece.MOVE_TIME)
		t.timeout.connect(move.take_piece.queue_free)

	elif move.type == Moves.CASTLE and not _is_in_check():
		var rook : Piece
		var x := pos.x
		if move.side == "long":
			rook = board[pos.y][0]; x += 1
		else:
			rook = board[pos.y][7]; x -= 1
		_move_piece(Vector2i(x, pos.y), rook)

	if move.has("promote"):
		board_node.queue_redraw()
		state = State.PROMOTING
		await selected_piece.promote_menu(pos)
		state = State.RUNNING

	selected_piece = null
	board_node.queue_redraw()
# ╰─────────────────────────────────────────────────────────────╯



# ╭──────────────────── BOT / NETWORK HELPERS ──────────────────╮
func _process_command(bot_move: String) -> void:
	var from_square := bot_move.substr(0, 2)
	var to_square   := bot_move.substr(bot_move.length() - 2, 2)
	var from_pos_arr = Util_Func._algebraic_to_coords(from_square)
	var to_pos_arr   = Util_Func._algebraic_to_coords(to_square)

	var piece = board[from_pos_arr[1]][from_pos_arr[0]]
	var pos   = Vector2i(to_pos_arr[0], to_pos_arr[1])

	if piece:
		moves = _get_legal_moves(piece)
		if moves.has(pos):
			var move = moves[pos]
			_move_piece(pos, piece)
			moves.clear()
			_process_turn(move, pos)

	board_node.queue_redraw()


func process_opponent_move(round_num: int) -> void:
	var move_from_db = await MultiplayerManager.wait_for_opponent_move(round_num)
	var from : Vector2i = move_from_db[0]
	var to   : Vector2i = move_from_db[1]

	var piece = board[from.y][from.x]
	if piece:
		moves = _get_legal_moves(piece)
		if moves.has(to):
			var move = moves[to]
			_move_piece(to, piece)
			moves.clear()
			_process_turn(move, to)

	board_node.queue_redraw()
	turn = "black" if turn == "white" else "white"
	self.round_num += 1
	_check_game_end()
# ╰─────────────────────────────────────────────────────────────╯



# ╭────────────────────────── UI ───────────────────────────────╮
func _game_over_dialog(text: String) -> void:
	var dlg := game_over_ui
	dlg.dialog_text = text
	dlg.add_cancel_button("Quit")
	dlg.confirmed.connect(get_tree().reload_current_scene)
	dlg.canceled .connect(get_tree().quit)
	dlg.popup_centered()
# ╰─────────────────────────────────────────────────────────────╯
