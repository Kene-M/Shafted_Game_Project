extends Control
@onready var ranged_list = $TabContainer/Ranged
@onready var melee_list = $TabContainer/Melee

signal weapon_selected(weapon_data: WeaponResource)

func _on_static_chest_2d_open_inventory() -> void:
	print("In Control...")
	visible = true
	var player = get_parent().get_node("MainChar")
	for i in player.ranged_weapons:
		var index = ranged_list.add_item(i.weapon_name)
		ranged_list.set_item_metadata(index, i)
	for i in player.melee_weapons:
		var index = melee_list.add_item(i.weapon_name)
		melee_list.set_item_metadata(index, i)
	get_tree().paused = true


func _on_button_pressed() -> void:
	visible = false
	ranged_list.clear()
	melee_list.clear()
	get_tree().paused = false

func _on_item_list_item_selected(index: int) -> void:
	var player = get_parent().get_node("MainChar")
	player.ranged_weapon = ranged_list.get_item_metadata(index)
	emit_signal("weapon_selected", ranged_list.get_item_metadata(index))
	
func _on_item_list_2_item_selected(index: int) -> void:
	var player = get_parent().get_node("MainChar")
	player.melee_weapon = melee_list.get_item_metadata(index)
	emit_signal("weapon_selected", melee_list.get_item_metadata(index))


func _on_static_chest_2d_close_inventory() -> void:
	pass # Replace with function body.
