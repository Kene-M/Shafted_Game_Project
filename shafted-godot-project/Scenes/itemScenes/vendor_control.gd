extends Control
@onready var buy_list = $"TabContainer/Buy"
@onready var sell_list = $"TabContainer/Sell"
@onready var rng = RandomNumberGenerator.new()
@onready var buy_list_set = false
@onready var icon_arr: Array = []

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
		
	
func _create_augments():
	var aug_args = [
			["AttackUp", rng.randi_range(5,20), AugType.Type.ATKADD, [3,2,0,0,0], "res://Assets/Player/Augments/AttackUpAugment.png"], 
			["HealthUp", rng.randi_range(50,200), AugType.Type.HPADD, [2,1,1,0,0], "res://Assets/Player/Augments/HealthUpAugment.png"],
			["SpeedUp", rng.randi_range(15,45), AugType.Type.SPDADD, [2,2,0,0,0], "res://Assets/Player/Augments/SpeedUpAugment.png"]
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
		new_aug.resource = aug[4]
		new_child.set_text(0, new_aug.aug_name)
		new_child.set_metadata(0, new_aug)
		new_child.set_icon(0, load(aug[4]))
		for i in range(1,6):
			if aug[3][i-1] != 0:
				new_child.set_text(i, str(aug[3][i-1]))
				new_child.set_icon(i, icon_arr[i-1])
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
			if i.price[j-1] != 0:
				new_child.set_text(j, str(i.price[j-1]))
				new_child.set_icon(j, icon_arr[j-1])
	
	
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
	

func _on_static_augment_vendor_2d_open_shop() -> void:
	self.visible = true
	var player = Autoload.main_char
	_update_inv_tree()
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
			_update_inv_tree()
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
		_update_inv_tree()
		player.remove_augment(sel_metadata)
		remove_child(sel_item)
		sel_item.call_deferred('free')
			
			
			
