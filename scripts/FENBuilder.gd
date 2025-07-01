extends Node

var boardRN: Array
var roundRN: int
var last_fen := ""

@onready var sf_socket = get_node("../StockfishSocket")

# Main function: prepares FEN and gets Stockfish move like "e2e4"
func send_info_to_sf(board_array: Array, round_number: int) -> String:
	boardRN = board_array
	roundRN = round_number

	# Generate FEN string
	var fen := ""
	for y in range(8):
		var empty := 0
		for x in range(8):
			var piece: Piece = boardRN[y][x]
			if piece == null:
				empty += 1
			else:
				if empty > 0:
					fen += str(empty)
					empty = 0
				fen += get_fen_symbol(piece)
		if empty > 0:
			fen += str(empty)
		if y != 7:
			fen += "/"

	var turn_fen:= ""
	if Global.player_color == "white":
		turn_fen = "b"
	else:
		turn_fen = "w"
	var castling = "-"
	var en_passant = "-"
	var halfmove = "0"
	var fullmove = str(roundRN)

	last_fen = "%s %s %s %s %s %s" % [fen, turn_fen, castling, en_passant, halfmove, fullmove]


	# Get best move string like "e2e4"
	var best_move = await sf_socket.get_best_move_from_server(last_fen , Global.bot_elo)
	return best_move


# Converts Piece object to single-character FEN symbol
func get_fen_symbol(piece: Piece) -> String:
	var symbol := "?"

	match piece.piece_id:
		piece.PAWN:   symbol = "p"
		piece.KNIGHT: symbol = "n"
		piece.BISHOP: symbol = "b"
		piece.ROOK:   symbol = "r"
		piece.QUEEN:  symbol = "q"
		piece.KING:   symbol = "k"

	if piece.team == "white":
		symbol = symbol.to_upper()

	return symbol
