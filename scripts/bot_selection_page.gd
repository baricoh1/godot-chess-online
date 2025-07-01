extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_texture_button_pressed() -> void:
	Global.bot_elo = 400
	get_tree().change_scene_to_file("res://scenes/game_mod_bot.tscn")


func _on_texture_button_2_pressed() -> void:
	Global.bot_elo = 900
	get_tree().change_scene_to_file("res://scenes/game_mod_bot.tscn")


func _on_texture_button_3_pressed() -> void:
	Global.bot_elo = 1500
	get_tree().change_scene_to_file("res://scenes/game_mod_bot.tscn")


func _on_texture_button_4_pressed() -> void:
	Global.bot_elo = 2000
	get_tree().change_scene_to_file("res://scenes/game_mod_bot.tscn")
