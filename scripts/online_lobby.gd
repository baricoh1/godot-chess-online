extends Control

@onready var my_code_label        : Label        = $Label
@onready var room_code_field      : LineEdit     = $LineEdit
@onready var room_found_popup     : AcceptDialog = $AcceptDialog
@onready var room_not_found_popup : AcceptDialog = $DeclineDialog


func _on_button_pressed() -> void:
	var entered_code := room_code_field.text.strip_edges()
	if entered_code.is_empty():
		return                         # ignore blank input

	var room_status := await MultiplayerManager.join_room(entered_code)
	if room_status:
		Global.guest = true

		# connect only once (one-shot) so duplicate clicks won’t stack
		if not room_found_popup.confirmed.is_connected(_start_game):
			room_found_popup.confirmed.connect(_start_game, CONNECT_ONE_SHOT)

		room_found_popup.popup_centered()

		# auto-start after 3 s unless the user already confirmed
		await get_tree().create_timer(3.0).timeout
		if room_found_popup.visible:
			room_found_popup.hide()
			_start_game()
	else:
		room_not_found_popup.popup_centered()


func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
