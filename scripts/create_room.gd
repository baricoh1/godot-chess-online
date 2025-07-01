extends Control

@onready var clock_anim  : AnimatedSprite2D   = $AnimatedSprite2D
@onready var code_label  : Label              = $Label
@onready var guest_popup : ConfirmationDialog = $ConfirmationDialog

func _ready() -> void:
	clock_anim.play("clock")
	code_label.text = Global.my_code

	MultiplayerManager.wait_for_guest(Global.my_code)   # start SSE
	MultiplayerManager.guest_joined.connect(_on_guest_joined)

	guest_popup.confirmed.connect(_start_game)          # only OK matters

func _on_guest_joined() -> void:
	guest_popup.popup_centered()                        # show popup

func _start_game() -> void:
	Global.host = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")
