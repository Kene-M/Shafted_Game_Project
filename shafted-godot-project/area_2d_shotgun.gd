extends Area2D
@export var weapon_data: WeaponResource
@export var item_type: String

func _ready():
	weapon_data = WeaponResource.new()
	weapon_data.weapon_name = "Shotgun"
	weapon_data.weapon_script = "res://Scripts/weaponScripts/weaponLogicScripts/shotgun.gd"
	item_type = "Ranged_Weapon"
