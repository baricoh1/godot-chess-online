extends Node


# ╭────────────────────── UTIL FUNCTIONS ───────────────────────╮
func _algebraic_to_coords(square: String) -> Array:
	var file := square[0].to_ascii_buffer()[0] - 'a'.to_ascii_buffer()[0]
	var rank := 8 - int(square[1])
	return [file, rank]
	
	

func _is_human_turn(current_turn: String) -> bool:
	if Global.vs_bot:
		return current_turn == Global.player_color
	if Global.vs_human:
		return (Global.host and current_turn == "white") or (Global.guest and current_turn == "black")
	return false
