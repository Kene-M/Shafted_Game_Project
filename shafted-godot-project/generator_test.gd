extends Node

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────

var min_rooms: int = 5
var max_rooms: int = 10
var generation_chance: int = 60

# ─────────────────────────────────────────────
# ROOM SCENE REFERENCES — assign in Inspector
# ─────────────────────────────────────────────

@export var scene_start: PackedScene
@export var scene_all_dirs: PackedScene
@export var scene_lr: PackedScene
@export var scene_ud: PackedScene

# ─────────────────────────────────────────────
# ENEMY SCENES — assign in Inspector
# ─────────────────────────────────────────────

@export var enemy_scenes: Array[PackedScene] = []
@export var min_enemies_per_room: int = 1
@export var max_enemies_per_room: int = 3

# ─────────────────────────────────────────────
# INTERNAL DATA
# ─────────────────────────────────────────────

var grid: Dictionary = {}
var placed_rooms: Dictionary = {}
var player_spawn_pos: Vector2 = Vector2.ZERO

const DIRECTIONS = {
	"North": Vector2i(0, -1),
	"South": Vector2i(0,  1),
	"East":  Vector2i(1,  0),
	"West":  Vector2i(-1, 0)
}

const OPPOSITE = {
	"North": "South",
	"South": "North",
	"East":  "West",
	"West":  "East"
}

var scene_map: Dictionary = {}

var scene_exits: Dictionary = {
	"West":                  ["West"],
	"East_West":             ["East", "West"],
	"North_South":           ["North", "South"],
	"East_North_South_West": ["East", "North", "South", "West"]
}


# ─────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────

func _ready():
	print("\n============================================================")
	print("DUNGEON GENERATOR STARTING")
	print("============================================================")
	
	scene_map["West"]                  = scene_start
	scene_map["East_West"]             = scene_lr
	scene_map["North_South"]           = scene_ud
	scene_map["East_North_South_West"] = scene_all_dirs

	var success = false
	while not success:
		grid.clear()
		placed_rooms.clear()
		for child in get_children():
			child.queue_free()
		success = _random_walk_logic()

	_assign_special_rooms()
	_print_map()
	call_deferred("_place_rooms")


## Called by game_manager to know where to put the player
func get_player_spawn_position() -> Vector2:
	return player_spawn_pos


# ─────────────────────────────────────────────
# STEP 1: RANDOM WALK
# ─────────────────────────────────────────────

func _random_walk_logic() -> bool:
	var start_pos = Vector2i(0, 0)
	grid[start_pos] = "start"
	var stack: Array = [start_pos]

	while stack.size() > 0 and grid.size() < max_rooms:
		var current = stack.back()
		var open_neighbors = _get_valid_open_neighbors(current)

		if open_neighbors.size() == 0:
			stack.pop_back()
			continue

		if randi_range(1, 100) > generation_chance:
			stack.pop_back()
			continue

		var next_pos = open_neighbors[randi() % open_neighbors.size()]
		grid[next_pos] = "normal"
		stack.append(next_pos)

	if grid.size() < min_rooms:
		return false

	var dead_end_count = 0
	for pos in grid.keys():
		if grid[pos] == "start":
			continue
		if _count_room_neighbors(pos) == 1:
			dead_end_count += 1

	if dead_end_count < 2:
		return false

	return true


func _get_valid_open_neighbors(pos: Vector2i) -> Array:
	var open = []
	var current_possible_exits = _get_possible_exits_for_pos(pos)

	for dir_name in current_possible_exits:
		var neighbor = pos + DIRECTIONS[dir_name]
		if grid.has(neighbor):
			continue
		var return_dir = OPPOSITE[dir_name]
		if not _any_scene_has_exit(return_dir):
			continue
		open.append(neighbor)

	return open


func _get_possible_exits_for_pos(pos: Vector2i) -> Array:
	if pos == Vector2i(0, 0):
		return scene_exits.get("West", [])
	var possible = []
	for dir_name in DIRECTIONS.keys():
		if _any_scene_has_exit(dir_name):
			possible.append(dir_name)
	return possible


func _any_scene_has_exit(dir_name: String) -> bool:
	for key in scene_exits.keys():
		if dir_name in scene_exits[key]:
			return true
	return false


# ─────────────────────────────────────────────
# STEP 2: SPECIAL ROOM ASSIGNMENT
# ─────────────────────────────────────────────

func _assign_special_rooms():
	var dead_ends: Array = []
	for pos in grid.keys():
		if grid[pos] == "start":
			continue
		if _count_room_neighbors(pos) == 1:
			dead_ends.append(pos)

	if dead_ends.size() == 0:
		return

	var boss_pos = dead_ends[0]
	var max_dist = 0
	for pos in dead_ends:
		var dist = abs(pos.x) + abs(pos.y)
		if dist > max_dist:
			max_dist = dist
			boss_pos = pos
	grid[boss_pos] = "boss"

	dead_ends.erase(boss_pos)
	if dead_ends.size() > 0:
		dead_ends.shuffle()
		grid[dead_ends[0]] = "treasure"


# ─────────────────────────────────────────────
# STEP 3: PLACE ROOMS
# ─────────────────────────────────────────────

func _place_rooms():
	print("\n------------------------------------------------------------")
	print("PLACING ROOMS")
	print("------------------------------------------------------------")
	
	var visit_queue: Array = [Vector2i(0, 0)]
	var visited: Dictionary = {}
	var retry_count: Dictionary = {}

	while visit_queue.size() > 0:
		var grid_pos = visit_queue.pop_front()

		if visited.has(grid_pos):
			continue

		var exits = _get_exits_for_pos(grid_pos)
		var key = _get_connection_key(exits)

		var packed: PackedScene
		if grid_pos == Vector2i(0, 0):
			packed = scene_start
		else:
			packed = _pick_best_scene(key, exits)

		if packed == null:
			visited[grid_pos] = true
			continue

		var room_instance = packed.instantiate()

		if grid_pos == Vector2i(0, 0):
			add_child(room_instance)
			room_instance.position = Vector2.ZERO
			print("Room at [0,0] (START): instantiated at ", room_instance.position)
		else:
			var snapped_pos = _calculate_position(grid_pos, room_instance)
			if snapped_pos == null:
				room_instance.free()
				retry_count[grid_pos] = retry_count.get(grid_pos, 0) + 1
				if retry_count[grid_pos] < 20:
					visit_queue.append(grid_pos)
				else:
					visited[grid_pos] = true
				continue
			add_child(room_instance)
			room_instance.position = snapped_pos
			print("Room at ", grid_pos, " (", grid[grid_pos], "): instantiated at ", room_instance.position)

		visited[grid_pos] = true
		placed_rooms[grid_pos] = room_instance
		room_instance.set_meta("grid_pos", grid_pos)
		room_instance.set_meta("room_type", grid[grid_pos])

		for dir_name in DIRECTIONS.keys():
			var neighbor = grid_pos + DIRECTIONS[dir_name]
			if grid.has(neighbor) and not visited.has(neighbor):
				visit_queue.append(neighbor)

	# Record player spawn position from the start room
	var start_room = placed_rooms.get(Vector2i(0, 0))
	if start_room:
		player_spawn_pos = start_room.global_position
		print("\nPlayer spawn position set to: ", player_spawn_pos)
	else:
		push_error("❌ Start room not found in placed_rooms!")
	
	print("------------------------------------------------------------")
	call_deferred("_spawn_enemies")


# ─────────────────────────────────────────────
# STEP 4: SPAWN ENEMIES (WITH MARGIN FIX)
# ─────────────────────────────────────────────

# CORRECTED _spawn_enemies() FUNCTION
# Replace your entire _spawn_enemies() function with this:

func _spawn_enemies():
	if enemy_scenes.size() == 0:
		return

	for grid_pos in placed_rooms.keys():
		var room_type = grid[grid_pos]

		# No enemies in start room or treasure room
		if room_type in ["start", "treasure"]:
			continue

		var room = placed_rooms[grid_pos]

		# Look for EnemySpawns container with Marker2D children
		var spawns_container = room.find_child("EnemySpawns", true, false)
		var spawn_points: Array = []

		if spawns_container:
			for child in spawns_container.get_children():
				if child is Marker2D:
					spawn_points.append(child.global_position)

		# If no markers, generate random positions within the floor area
		if spawn_points.size() == 0:
			var floor_layer = room.find_child("floor", true, false)
			if floor_layer and floor_layer is TileMapLayer:
				var used = floor_layer.get_used_rect()
				var tile_size = floor_layer.tile_set.tile_size as Vector2
				
				# Convert Rect2i to Rect2 to avoid type issues
				var spawn_rect = Rect2(
					Vector2(used.position),
					Vector2(used.size)
				)
				
				# Use margin to keep enemies away from walls/edges
				var margin = 4.0
				spawn_rect.position = spawn_rect.position + Vector2(margin, margin)
				spawn_rect.size = spawn_rect.size - Vector2(margin * 2, margin * 2)
				
				var count = randi_range(min_enemies_per_room, max_enemies_per_room)
				for i in count:
					var rand_x = randf_range(spawn_rect.position.x, spawn_rect.position.x + spawn_rect.size.x)
					var rand_y = randf_range(spawn_rect.position.y, spawn_rect.position.y + spawn_rect.size.y)
					var pos = room.global_position + Vector2(rand_x, rand_y) * tile_size
					spawn_points.append(pos)

		# Spawn enemies at the chosen points
		var enemy_count = mini(
			randi_range(min_enemies_per_room, max_enemies_per_room),
			spawn_points.size()
		)

		spawn_points.shuffle()

		# Boss rooms get more enemies
		if room_type == "boss":
			enemy_count = spawn_points.size()

		for i in enemy_count:
			var enemy_scene = enemy_scenes[randi() % enemy_scenes.size()]
			var enemy = enemy_scene.instantiate()
			enemy.global_position = spawn_points[i]
			room.add_child(enemy)


func _calculate_position(grid_pos: Vector2i, new_instance: Node2D) -> Variant:
	for dir_name in DIRECTIONS.keys():
		var neighbor_grid_pos = grid_pos + DIRECTIONS[dir_name]

		if not placed_rooms.has(neighbor_grid_pos):
			continue

		var placed_neighbor = placed_rooms[neighbor_grid_pos]

		var neighbor_exit_name = "Exit" + OPPOSITE[dir_name]
		var our_entry_name     = "Exit" + dir_name

		var neighbor_marker = placed_neighbor.find_child(neighbor_exit_name, true, false)
		var our_marker      = new_instance.find_child(our_entry_name, true, false)

		if neighbor_marker == null or our_marker == null:
			continue

		return placed_neighbor.position + neighbor_marker.position - our_marker.position

	return null


# ─────────────────────────────────────────────
# CONSOLE PRINT
# ─────────────────────────────────────────────

func _print_map():
	var min_x = 0; var max_x = 0
	var min_y = 0; var max_y = 0
	for pos in grid.keys():
		if pos.x < min_x: min_x = pos.x
		if pos.x > max_x: max_x = pos.x
		if pos.y < min_y: min_y = pos.y
		if pos.y > max_y: max_y = pos.y

	print("\n------------------------------------------------------------")
	print("GENERATED DUNGEON MAP")
	print("------------------------------------------------------------")
	print("Rooms generated: ", grid.size())
	print("")
	for y in range(min_y, max_y + 1):
		var row = ""
		for x in range(min_x, max_x + 1):
			var pos = Vector2i(x, y)
			if grid.has(pos):
				match grid[pos]:
					"start":    row += "[*]"
					"boss":     row += "[B]"
					"treasure": row += "[T]"
					_:          row += "[ ]"
			else:
				row += "   "
		print(row)
	print("")
	print("Legend: [*]=Start  [ ]=Normal  [B]=Boss  [T]=Treasure")
	print("------------------------------------------------------------\n")


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

func _pick_best_scene(key: String, exits: Array) -> PackedScene:
	if scene_map.has(key):
		return scene_map[key]
	if scene_map.has("East_North_South_West"):
		return scene_map["East_North_South_West"]
	return null


func _get_exits_for_pos(pos: Vector2i) -> Array:
	var exits = []
	for dir_name in DIRECTIONS.keys():
		if grid.has(pos + DIRECTIONS[dir_name]):
			exits.append(dir_name)
	return exits


func _get_connection_key(exits: Array) -> String:
	var sorted = exits.duplicate()
	sorted.sort()
	return "_".join(sorted)


func _count_room_neighbors(pos: Vector2i) -> int:
	var count = 0
	for dir in DIRECTIONS.values():
		if grid.has(pos + dir):
			count += 1
	return count
