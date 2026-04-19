extends VBoxContainer

func _on_save_pressed():
	save_manager.save_game(false)

func _on_load_pressed():
	save_manager.load_game()

func _on_kill_pressed():
	var player = Autoload.main_char
	player.take_damage(10)
