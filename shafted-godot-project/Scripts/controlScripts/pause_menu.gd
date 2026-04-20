extends Control

@onready var home_btn: Button = $VBoxContainer/HomeScreenButton
@onready var save_btn: Button = $VBoxContainer/SaveGameButton
@onready var load_btn: Button = $VBoxContainer/LoadGameButton
@onready var exit_btn: Button = $VBoxContainer/ExitButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


func toggle_pause() -> void:
	get_tree().paused = !get_tree().paused
	visible = get_tree().paused


# =========================
# BUTTON FUNCTIONS
# =========================

func _on_home_screen_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/UI/StartMenu.tscn")


func _on_save_game_button_pressed() -> void:
	save_manager.save_game(false)


func _on_load_game_button_pressed() -> void:
	get_tree().paused = false
	save_manager.is_loading_run = true
	get_tree().change_scene_to_file("res://Scenes/game.tscn")


func _on_exit_button_pressed() -> void:
	get_tree().quit()
