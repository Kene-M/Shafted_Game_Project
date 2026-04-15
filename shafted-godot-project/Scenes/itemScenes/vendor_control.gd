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
	var tree = $TabContainer/Tree
	var root = tree.create_item()
	tree.hide_root = true
	while len(aug_args) != 0:
		var new_child = tree.create_item(root)
		var aug = aug_args.pick_random()
		var new_aug = Augment.new()
		new_aug.aug_name = aug[0]
		new_aug.data = aug[1]
		new_aug.type = aug[2]
		new_child.set_text(0, new_aug.aug_name)
		new_child.set_metadata(0, new_aug)
		for i in range(1,6):
			if aug[3][i-1] != 0:
				new_child.set_text(i, str(aug[3][i-1]))
		var index = buy_list.add_item(new_aug.aug_name)
		buy_list.set_item_metadata(index, new_aug)
		aug_args.erase(aug)
	buy_list_set = true
	

func _on_static_augment_vendor_2d_open_shop() -> void:
	self.visible = true
	var player = Autoload.main_char
	for i in player.augments:
		var index = sell_list.add_item(i.aug_name)
		sell_list.set_item_metadata(index, i)
	if buy_list_set == false:
		_create_augments()
	
	
	get_tree().paused = true
	
	


func _on_button_pressed() -> void:
	self.visible = false
	sell_list.clear()
	get_tree().paused = false


func _on_tree_cell_selected() -> void:
	var tree = $TabContainer/Tree
	var sel_item = tree.get_selected()
	var sel_metadata = sel_item.get_metadata(0)
	if sel_metadata:
		print(sel_metadata.aug_name)
		var player = Autoload.main_char
		player.add_augment(sel_metadata)
		remove_child(sel_item)
		sel_item.call_deferred('free')
		
