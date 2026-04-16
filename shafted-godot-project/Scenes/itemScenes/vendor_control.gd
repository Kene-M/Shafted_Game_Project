extends Control
@onready var buy_list = $"TabContainer/Buy"
@onready var sell_list = $"TabContainer/Sell"
@onready var rng = RandomNumberGenerator.new()
@onready var buy_list_set = false

func _create_augments():
	var aug_args = [
			["AttackUp", rng.randi_range(5,20), AugType.Type.ATKADD, [3,2,0,0,0]], 
			["HealthUp", rng.randi_range(50,200), AugType.Type.HPADD, [2,1,1,0,0]],
			["SpeedUp", rng.randi_range(15,45), AugType.Type.SPDADD, [2,2,0,0,0]]
		]
	var tree = $TabContainer/BuyTree
	var root = tree.create_item()
	tree.hide_root = true
	while len(aug_args) != 0:
		var new_child = tree.create_item(root)
		var aug = aug_args.pick_random()
		var new_aug = Augment.new()
		new_aug.aug_name = aug[0]
		new_aug.data = aug[1]
		new_aug.type = aug[2]
		new_aug.price = aug[3]
		new_child.set_text(0, new_aug.aug_name)
		new_child.set_metadata(0, new_aug)
		for i in range(1,6):
			if aug[3][i-1] != 0:
				new_child.set_text(i, str(aug[3][i-1]))
		aug_args.erase(aug)
	buy_list_set = true
	
func _populate_sell_tree():
	var tree = $TabContainer/SellTree
	tree.clear()
	var player = Autoload.main_char
	var root = tree.create_item()
	tree.hide_root = true
	for i in player.augments:
		var new_child = tree.create_item(root)
		new_child.set_text(0, i.aug_name)
		new_child.set_metadata(0, i)
		for j in range(1,6):
			new_child.set_text(j, str(i.price[j-1]))
	

func _update_inv_label():
	var player = Autoload.main_char
	var inv_label = $PlayerInvLabel
	var inv_str = "Your Resources: "
	for i in player.resource_inv:
		inv_str += str(i) + " "
	inv_label.text = inv_str

func _on_static_augment_vendor_2d_open_shop() -> void:
	self.visible = true
	var player = Autoload.main_char
	_update_inv_label()
	if buy_list_set == false:
		_create_augments()
	_populate_sell_tree()
	get_tree().paused = true
	
	


func _on_button_pressed() -> void:
	self.visible = false
	get_tree().paused = false


func _on_buy_tree_cell_selected() -> void:
	var tree = $TabContainer/BuyTree
	var sel_item = tree.get_selected()
	var sel_metadata = sel_item.get_metadata(0)
	if sel_metadata:
		var player = Autoload.main_char
		var has_recs = true
		print(sel_metadata.aug_name)
		for i in range(len(sel_metadata.price)):
			if player.resource_inv[i] < sel_metadata.price[i]:
				has_recs = false		
		if has_recs:
			for i in range(len(sel_metadata.price)):
				player.resource_inv[i] -= sel_metadata.price[i]
				sel_metadata.price[i] = sel_metadata.price[i]/2
			_update_inv_label()
			player.add_augment(sel_metadata)
			_populate_sell_tree()
			remove_child(sel_item)
			sel_item.call_deferred('free')
		else:
			print("NOT ENOUGH RECS")


func _on_sell_tree_cell_selected() -> void:
	var tree = $TabContainer/SellTree
	var sel_item = tree.get_selected()
	var sel_metadata = sel_item.get_metadata(0)
	if sel_metadata:
		var player = Autoload.main_char
		for i in range(len(sel_metadata.price)):
			player.resource_inv[i] += sel_metadata.price[i]
		_update_inv_label()
		player.remove_augment(sel_metadata)
		remove_child(sel_item)
		sel_item.call_deferred('free')
			
			
			
