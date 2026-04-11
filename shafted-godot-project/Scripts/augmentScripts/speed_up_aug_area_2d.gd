extends Area2D
@export var aug: Augment
@export var item_type: String = "Augment"

func _ready():
	aug = Augment.new()
	aug.aug_name = "SpeedUp"
	aug.data = 25
	aug.type = AugType.Type.SPDADD
