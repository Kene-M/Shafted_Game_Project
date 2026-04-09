extends StaticBody2D
@onready var in_area = false
@onready var item_list = $ItemList
@onready var label = $Label

signal open_inventory()
signal close_inventory()

func _physics_process(delta: float) -> void:
	if in_area == true:
		if Input.is_action_just_pressed("interact") == true:
			print("CHEST OPENED")
			emit_signal("open_inventory")

func _on_area_2d_area_entered(area: Area2D) -> void:
	label.visible = true
	in_area = true


func _on_area_2d_area_exited(area: Area2D) -> void:
	in_area = false
	label.visible = false
