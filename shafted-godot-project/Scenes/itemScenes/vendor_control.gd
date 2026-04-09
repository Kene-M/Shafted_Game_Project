extends Control
@onready var buy_list = $"TabContainer/Buy"
@onready var sell_list = $"TabContainer/Sell"
@onready var rng = RandomNumberGenerator.new()
@onready var buy_list_set = false

func _create_augments():
	var aug_args = [
			["AttackUp", rng.randi_range(5,20), AugType.Type.ATKADD], 
			["HealthUp", rng.randi_range(50,200), AugType.Type.HPADD],
			["SpeedUp", rng.randi_range(15,45), AugType.Type.SPDADD]
		]
	while len(aug_args) != 0:
		var aug = aug_args.pick_random()
		var new_aug = Augment.new()
		new_aug.aug_name = aug[0]
		new_aug.data = aug[1]
		new_aug.type = aug[2]
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
