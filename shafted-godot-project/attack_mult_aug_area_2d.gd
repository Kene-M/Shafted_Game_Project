extends Area2D
@export var aug: Augment
@export var item_type: String = "Augment"

func _ready():
	$"../AnimatedSprite2D".play()
	aug = Augment.new()
	aug.aug_name = "AttackMult"
	aug.data = randf_range(0.2, 0.7)
	aug.type = AugType.Type.ATKMULT
	aug.price = [3,3,1,0,0]
	aug.resource = "res://Assets/Player/Augments/AttackUpAugment.png" 
