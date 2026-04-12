extends Node
class_name ItemPlacer

# ─────────────────────────────────────────────
# CONFIGURATION — assign in Inspector
# ─────────────────────────────────────────────

# The placeholder item scene to instantiate for all drops
@export var item_scene: PackedScene

# Loot table used for normal rooms (chance-based)
@export var loot_table_random: LootTable

# Loot table used for treasure rooms (guaranteed)
@export var loot_table_guaranteed: LootTable

# Probability (0.0–1.0) that any given spawn_random point
# actually spawns something in a normal room.
# 0.4 = 40% chance per spawn point.
@export var global_spawn_chance: float = 0.4


# ─────────────────────────────────────────────
# ENTRY POINT
# Called by the dungeon generator after all rooms are placed.
# Pass in the placed_rooms dictionary from dungeon_generator.gd.
# ─────────────────────────────────────────────

func populate_rooms(placed_rooms: Dictionary):
	for grid_pos in placed_rooms.keys():
		var room_instance = placed_rooms[grid_pos]
		var room_type = room_instance.get_meta("room_type", "normal")

		if room_type == "treasure":
			_spawn_guaranteed_loot(room_instance)
		else:
			# Boss and normal rooms both use random spawning.
			# Boss rooms will feel harder because items are rare.
			_process_random_spawns(room_instance)


# ─────────────────────────────────────────────
# GUARANTEED SPAWN — used for treasure rooms
# Every spawn_guaranteed marker in this room gets an item.
# ─────────────────────────────────────────────

func _spawn_guaranteed_loot(room_instance: Node2D):
	# get_children_in_group finds all nodes in the group within this room's subtree
	var spawn_points = _get_spawn_points(room_instance, "spawn_guaranteed")

	if spawn_points.is_empty():
		print("INFO: Treasure room has no 'spawn_guaranteed' markers — add some to the scene")
		return

	for point in spawn_points:
		var item_id = loot_table_guaranteed.pick_item()
		_spawn_item(item_id, point.global_position, room_instance)


# ─────────────────────────────────────────────
# RANDOM SPAWN — used for normal/boss rooms
# Each spawn_random marker rolls against global_spawn_chance.
# ─────────────────────────────────────────────

func _process_random_spawns(room_instance: Node2D):
	var spawn_points = _get_spawn_points(room_instance, "spawn_random")

	for point in spawn_points:
		# Roll — skip this point if the roll fails
		if randf() > global_spawn_chance:
			continue

		var item_id = loot_table_random.pick_item()
		_spawn_item(item_id, point.global_position, room_instance)


# ─────────────────────────────────────────────
# INSTANTIATE ITEM
# Creates the placeholder item at the given world position,
# parented to the room so it unloads when the room does.
# ─────────────────────────────────────────────

func _spawn_item(item_id: String, world_pos: Vector2, room_instance: Node2D):
	if item_scene == null:
		print("ERROR: item_scene not assigned in ItemPlacer Inspector")
		return

	var item = item_scene.instantiate()

	# Parent to the room so the item unloads with the room
	room_instance.add_child(item)
	item.global_position = world_pos

	# Set the label text to the item_id so you can see what spawned
	# This assumes your placeholder scene has a Label child node
	var label = item.get_node_or_null("Label")
	if label:
		label.text = item_id

	print("Spawned '", item_id, "' at ", world_pos, " in ", room_instance.name)


# ─────────────────────────────────────────────
# HELPER
# Returns all Marker2D nodes inside a room that belong to the given group.
# ─────────────────────────────────────────────

func _get_spawn_points(room_instance: Node2D, group_name: String) -> Array:
	var result = []
	# get_tree().get_nodes_in_group gets ALL nodes in the scene tree with that group.
	# We filter down to only those that are children of this specific room.
	for node in room_instance.get_tree().get_nodes_in_group(group_name):
		# Check this node actually lives inside this room's subtree
		if room_instance.is_ancestor_of(node):
			result.append(node)
	return result
