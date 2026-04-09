extends Area2D
@export var aug: Augment
@export var item_type: String = "Augment"

func _ready():
	$"../AnimatedSprite2D".play()
	aug = Augment.new()
	aug.aug_name = "AttackUp"
	aug.data = 10
	aug.type = AugType.Type.ATKADD
