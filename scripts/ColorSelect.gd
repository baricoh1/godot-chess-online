extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_whit_p_selected() -> void:
	Global.player_color = "white"
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_black_p_selected() -> void:
	Global.player_color = "black"
	get_tree().change_scene_to_file("res://scenes/game.tscn")
