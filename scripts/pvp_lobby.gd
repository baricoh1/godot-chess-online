extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_join_room_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/join_lobby.tscn")


func _on_create_room_pressed() -> void:
	MultiplayerManager.create_room(Global.my_code)
	get_tree().change_scene_to_file("res://scenes/create_room.tscn")
