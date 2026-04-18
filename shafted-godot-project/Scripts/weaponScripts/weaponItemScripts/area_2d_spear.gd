extends Area2D
@export var weapon_data: WeaponResource
@export var item_type: String

func _ready():
	weapon_data = WeaponResource.new()
	weapon_data.weapon_name = "Spear"
	weapon_data.weapon_script = "res://Scripts/weaponScripts/weaponLogicScripts/spear.gd"
	item_type = "Melee_Weapon"
