extends Button





func _on_pressed() -> void:
	print("BUTTON PRESSED")
	get_tree().reload_current_scene()
