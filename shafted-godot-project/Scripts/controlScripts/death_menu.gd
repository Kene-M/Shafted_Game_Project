extends Control


func _on_button_pressed() -> void:
	print("BUTTON PRESSED")
	get_tree().reload_current_scene()
