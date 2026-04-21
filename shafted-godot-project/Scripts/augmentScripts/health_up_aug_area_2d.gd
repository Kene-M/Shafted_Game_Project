extends Area2D
@export var aug: Augment
@export var item_type: String = "Augment"

func _ready():
	aug = Augment.new()
	aug.aug_name = "HealthUp"
	aug.data = 100
	aug.type = AugType.Type.HPADD
	aug.price = [2,1,1,0,0]
	aug.resource = "res://Assets/Player/Augments/HealthUpAugment.png" 
