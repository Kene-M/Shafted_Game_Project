extends AnimatableBody2D
@export var speed = 0
@export var direction = Vector2(0,0)
@onready var sprite = $Sprite2D

#func _ready():
	#var img = Image.load_from_file("res://Brick2-1.jpg")
	#var texture = ImageTexture.create_from_image(img)
	#sprite.texture = texture
	#sprite.scale = Vector2(0.01, 0.01)
	
func _physics_process(delta: float) -> void:
	position += (direction * speed) * delta
