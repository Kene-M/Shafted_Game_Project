extends Control
@onready var icon_arr: Array = []
@onready var filled: bool = false

func _ready() -> void:
	var rec_dir = DirAccess.open("res://Assets/Props/Resources/")
	if rec_dir:
		rec_dir.list_dir_begin()
		var rec_file = rec_dir.get_next()
		while rec_file != "":
			if not rec_dir.current_is_dir():
				var ext = rec_file.get_extension()
				if ext == "png":
					var rec_path = rec_dir.get_current_dir().path_join(rec_file)
					var texture = load(rec_path)
					icon_arr.append(texture)
			rec_file = rec_dir.get_next()


func _create_weapons():
	var weapon_args = [
			["Rifle", "res://Scripts/weaponScripts/weaponLogicScripts/gun.gd", [2,2,1,0,0], "Ranged"],
			["Shotgun", "res://Scripts/weaponScripts/weaponLogicScripts/shotgun.gd", [3,2,1,1,0], "Ranged"],
			["Sword", "res://Scripts/weaponScripts/weaponLogicScripts/sword.gd", [2,3,1,0,0], "Melee"],
			["Spear", "res://Scripts/weaponScripts/weaponLogicScripts/spear.gd", [2,2,2,0,0], "Melee"]
		]
	var tree = $TabContainer/Crafting
	var root = tree.create_item()
	tree.hide_root = true
	while len(weapon_args) != 0:
		var new_child = tree.create_item(root)
		var weapon = weapon_args.pick_random()
		var new_weapon = WeaponResource.new()
		new_weapon.weapon_name = weapon[0]
		new_weapon.weapon_script = weapon[1]
		new_weapon.price = weapon[2]
		new_weapon.weapon_type = weapon[3]
		new_child.set_text(0, new_weapon.weapon_name)
		new_child.set_metadata(0, new_weapon)
		for i in range(1,6):
			if weapon[2][i-1] != 0:
				new_child.set_text(i, str(weapon[2][i-1]))
				new_child.set_icon(i, icon_arr[i-1])
		weapon_args.erase(weapon)


func _on_static_weapon_crafter_2d_open_crafter() -> void:
	self.visible = true
	var player = Autoload.main_char
	_update_inv_tree()
	if filled == false:
		_create_weapons()
		filled = true
	get_tree().paused = true
	


func _update_inv_tree():
	var player = Autoload.main_char
	var tree = $PlayerInvTree
	tree.clear()
	var root = tree.create_item()
	tree.hide_root = true
	var first_child = tree.create_item(root)
	first_child.set_text(0, "Your Resources:")
	for i in range(len(player.resource_inv)):
		var new_child = tree.create_item(root)
		new_child.set_text(0, str(player.resource_inv[i]))
		new_child.set_icon(0, icon_arr[i])




func _on_crafting_cell_selected() -> void:
	var tree = $TabContainer/Crafting
	var sel_item = tree.get_selected()
	var sel_metadata = sel_item.get_metadata(0)
	if sel_metadata:
		var player = Autoload.main_char
		var has_recs = true
		for i in range(len(sel_metadata.price)):
			if player.resource_inv[i] < sel_metadata.price[i]:
				has_recs = false		
		if has_recs:
			for i in range(len(sel_metadata.price)):
				player.resource_inv[i] -= sel_metadata.price[i]
				sel_metadata.price[i] = sel_metadata.price[i]/2
			_update_inv_tree()
			player.add_weapon(sel_metadata)
			remove_child(sel_item)
			sel_item.call_deferred('free')
		else:
			print("NOT ENOUGH RECS")


func _on_button_pressed() -> void:
	print("CRAFTING BUTTON PRESSED")
	self.visible = false
	get_tree().paused = false
