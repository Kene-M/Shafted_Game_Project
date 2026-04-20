@tool
extends EditorScript

# just a simple map offset maker to reuse some of my hand painted rooms
const SOURCE_SCENE = "res://Scenes/room_scenes/down_deadend.tscn"
const OUTPUT_SCENE = "res://Scenes/room_scenes/up_deadend1.tscn"
const FLIP_H = false
const FLIP_V = false
const ROTATE_DEGREES = 90  # go inc by 90 deg only!!!!!!!!!!!!!!!!!!

func _run() -> void:
	var source = load(SOURCE_SCENE).instantiate()

	for child in source.get_children():
		if child is TileMapLayer:
			var used_rect = child.get_used_rect()
			var tile_size = child.tile_set.tile_size
			var map_w = used_rect.size.x * tile_size.x
			var map_h = used_rect.size.y * tile_size.y

			if FLIP_H:
				child.scale.x = -1
				child.position.x += map_w

			if FLIP_V:
				child.scale.y = -1
				child.position.y += map_h

			# rotation and compensate position
			match ROTATE_DEGREES:
				90:
					child.rotation_degrees = 90
					child.position.x += map_w  # shift right by original width
				180:
					child.rotation_degrees = 180
					child.position.x += map_w
					child.position.y += map_h
				270:
					child.rotation_degrees = 270
					child.position.y += map_h  # shift down by original height

	var packed = PackedScene.new()
	packed.pack(source)
	var err = ResourceSaver.save(packed, OUTPUT_SCENE)

	if err == OK:
		print("Saved to: ", OUTPUT_SCENE)
	else:
		print("ERROR saving: ", err)
