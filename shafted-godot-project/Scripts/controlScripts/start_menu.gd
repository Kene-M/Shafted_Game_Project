extends Control

@onready var new_game_btn: Button = $NewGameButton
@onready var load_game_btn: Button = $LoadGameButton
@onready var options_btn: Button = $CreditsButton
@onready var exit_btn: Button = $ExitButton

const SPAWNROOM_SCENE := "res://scenes/rooms/spawnRoom.tscn"

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(SPAWNROOM_SCENE)

func _on_options_pressed() -> void:
	pass  # hook up options menu later

func _on_exit_pressed() -> void:
	get_tree().quit()
