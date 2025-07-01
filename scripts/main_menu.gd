extends Control

const FallingPiece := preload("res://scenes/falling_piece.tscn")

var piece_scale: int

func _ready():
	set_window()
	randomize_background()

func _unhandled_input(event):
	if event.is_action_pressed("change_bg"):
		randomize_background()
		
func set_window():
	var screen_size = DisplayServer.screen_get_size()

	var lowest_dimension = screen_size[screen_size.min_axis_index()]
	get_window().size = Vector2i.ONE * lowest_dimension * 0.75

	DisplayServer.window_set_position(
		DisplayServer.screen_get_position() +
		(DisplayServer.screen_get_size() - DisplayServer.window_get_size())/2
	)

func randomize_background():
	randomize()
	
	# Disable the Ground
	$Background/Ground.collision_layer = randi() % 2 + 1
	
	piece_scale = randi() % 2 + 1
	$Background/AddPieceTimer.wait_time = 0.25 if piece_scale == 2 else 0.1

func add_falling_piece():
	get_tree().call_group("falling_pieces", "delete_if_not_visible")
	
	var piece := FallingPiece.instantiate()
	piece.add_to_group("falling_pieces")
	
	piece.get_node("CollisionShape").shape.radius *= piece_scale
	piece.get_node("Sprite").scale *= piece_scale
	
	piece.position.x = randi_range(0, 256)
	piece.position.y = -2 * Global.TILE_SIZE * piece_scale
	
	$Background.add_child(piece)

func _on_play_bot_pressed():
	Global.vs_bot = true
	get_tree().change_scene_to_file("res://scenes/bot_selection_board.tscn")

func generate_random_code(length := 6) -> String:
	var charset := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var code := ""
	for i in length:
		var random_index := randi() % charset.length()
		code += charset[random_index]
	return code

func _on_play_with_friend_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/pvp_lobby.tscn")
	Global.my_code = generate_random_code()
	Global.vs_human = true
