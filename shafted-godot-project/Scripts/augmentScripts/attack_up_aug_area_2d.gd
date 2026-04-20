extends Area2D
@export var aug: Augment
@export var item_type = "Augment"

func _ready():
	aug = Augment.new()
	aug.aug_name = "AttackUp"
	aug.data = 10
	aug.type = AugType.Type.ATKADD
	aug.price = [3,2,0,0,0]
	aug.resource = "res://Assets/Player/Augments/AttackUpAugment.png" 
