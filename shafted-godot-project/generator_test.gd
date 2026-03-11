extends Node

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────

var min_rooms: int = 5
var max_rooms: int = 10
var generation_chance: int = 60
var room_display_radius: float = 1500.0

# ─────────────────────────────────────────────
# ROOM SCENE REFERENCES — assign in Inspector
# ─────────────────────────────────────────────

@export var scene_start: PackedScene       # first_room.tscn        exits: ExitWest only
@export var scene_all_dirs: PackedScene    # tri_connectl_lud.tscn   exits: ExitN/S/E/W
@export var scene_lr: PackedScene          # lr_connector.tscn       exits: ExitEast/West

# ─────────────────────────────────────────────
# INTERNAL DATA
# ─────────────────────────────────────────────

var grid: Dictionary = {}
var placed_rooms: Dictionary = {}
var _camera_ready: bool = false

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
	"East_North_South_West": ["East", "North", "South", "West"]
}


# ─────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────

func _ready():
	scene_map["West"]                  = scene_start
	scene_map["East_West"]             = scene_lr
	scene_map["East_North_South_West"] = scene_all_dirs

	var success = false
	while not success:
		grid.clear()
		placed_rooms.clear()
		for child in get_children():
			if child is Camera2D:
				continue
			child.queue_free()
		success = _random_walk_logic()

	_assign_special_rooms()
	_print_map()

	# Diagnostic: confirm which markers each scene can find at runtime
	for key in scene_map.keys():
		var inst = scene_map[key].instantiate()
		var found = []
		for dir in ["North", "South", "East", "West"]:
			if inst.find_child("Exit" + dir, true, false) != null:
				found.append(dir)
		print("Scene '", key, "' markers found: ", found)
		inst.free()

	_place_rooms()


func _process(_delta):
	if not _camera_ready:
		_camera_ready = true
		_setup_overview_camera()


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

	return grid.size() >= min_rooms


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
		print("INFO: No dead ends found — boss and treasure rooms not assigned")
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
	else:
		print("INFO: Only one dead end found — no treasure room assigned")


# ─────────────────────────────────────────────
# STEP 3: PLACE ROOMS
# ─────────────────────────────────────────────

func _place_rooms():
	var visit_queue: Array = [Vector2i(0, 0)]
	var visited: Dictionary = {}
	# Track retries per room to avoid an infinite loop if a room
	# genuinely has no valid anchor at all
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
			print("INFO: Skipping room at ", grid_pos,
				" — no valid scene for key '", key, "'")
			visited[grid_pos] = true
			continue

		var room_instance = packed.instantiate()

		if grid_pos == Vector2i(0, 0):
			add_child(room_instance)
			room_instance.position = Vector2.ZERO
		else:
			var snapped_pos = _calculate_position(grid_pos, room_instance)
			if snapped_pos == null:
				room_instance.free()
				retry_count[grid_pos] = retry_count.get(grid_pos, 0) + 1
				if retry_count[grid_pos] < 20:
					# Not all neighbors placed yet — try again later
					visit_queue.append(grid_pos)
				else:
					print("WARNING: Giving up on room at ", grid_pos,
						" — no anchor found after retries")
					visited[grid_pos] = true
				continue
			add_child(room_instance)
			room_instance.position = snapped_pos

		visited[grid_pos] = true
		placed_rooms[grid_pos] = room_instance
		room_instance.set_meta("grid_pos", grid_pos)
		room_instance.set_meta("room_type", grid[grid_pos])

		for dir_name in DIRECTIONS.keys():
			var neighbor = grid_pos + DIRECTIONS[dir_name]
			if grid.has(neighbor) and not visited.has(neighbor):
				visit_queue.append(neighbor)


func _calculate_position(grid_pos: Vector2i, new_instance: Node2D) -> Variant:
	for dir_name in DIRECTIONS.keys():
		var neighbor_grid_pos = grid_pos + DIRECTIONS[dir_name]

		if not placed_rooms.has(neighbor_grid_pos):
			continue

		var placed_neighbor = placed_rooms[neighbor_grid_pos]

		# dir_name is the direction FROM us TO the neighbor.
		# The neighbor's exit pointing back TOWARD us is the OPPOSITE direction.
		# Our entry pointing TOWARD the neighbor is dir_name itself.
		var neighbor_exit_name = "Exit" + OPPOSITE[dir_name]  # was "Exit" + dir_name — WRONG
		var our_entry_name     = "Exit" + dir_name             # was "Exit" + OPPOSITE[dir_name] — WRONG

		var neighbor_marker = placed_neighbor.find_child(neighbor_exit_name, true, false)
		var our_marker      = new_instance.find_child(our_entry_name, true, false)

		if neighbor_marker == null or our_marker == null:
			continue

		return placed_neighbor.position + neighbor_marker.position - our_marker.position

	return null


# ─────────────────────────────────────────────
# STEP 4: OVERVIEW CAMERA
# ─────────────────────────────────────────────

func _setup_overview_camera():
	if placed_rooms.size() == 0:
		return

	var cam = get_node_or_null("OverviewCamera")
	if cam == null:
		print("ERROR: OverviewCamera node not found")
		return

	# Build bounding box from raw room positions first
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF

	for room in placed_rooms.values():
		var p = room.position
		if p.x < min_x: min_x = p.x
		if p.x > max_x: max_x = p.x
		if p.y < min_y: min_y = p.y
		if p.y > max_y: max_y = p.y

	# Pad all four sides equally after finding true extents
	min_x -= room_display_radius
	max_x += room_display_radius
	min_y -= room_display_radius
	max_y += room_display_radius

	# Center is the midpoint of the padded box
	var center = Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)
	cam.position = center
	cam.make_current()

	var viewport_size = get_viewport().get_visible_rect().size
	var map_width  = max_x - min_x
	var map_height = max_y - min_y

	var zoom_x = viewport_size.x / map_width
	var zoom_y = viewport_size.y / map_height
	# Take the smaller zoom so the larger dimension always fits fully
	var zoom_level = min(zoom_x, zoom_y) * 0.85
	cam.zoom = Vector2(zoom_level, zoom_level)


# ─────────────────────────────────────────────
# STEP 5: CONSOLE PRINT
# ─────────────────────────────────────────────

func _print_map():
	var min_x = 0; var max_x = 0
	var min_y = 0; var max_y = 0
	for pos in grid.keys():
		if pos.x < min_x: min_x = pos.x
		if pos.x > max_x: max_x = pos.x
		if pos.y < min_y: min_y = pos.y
		if pos.y > max_y: max_y = pos.y

	print("=== DUNGEON MAP ===")
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


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

func _pick_best_scene(key: String, exits: Array) -> PackedScene:
	if scene_map.has(key):
		return scene_map[key]
	# Use all-directions fallback for any unmatched shape, including dead ends.
	# Dead ends will show open doorways for now — fix this when dedicated dead-end
	# room scenes are built.
	if scene_map.has("East_North_South_West"):
		print("INFO: No exact scene for key '", key, "' — using all-directions fallback")
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


""" # Base logic proof of concept with printing square brackets
extends Node

# ─────────────────────────────────────────────
# CONFIGURATION (mirrors your @export variables from section 5.4.2)
# ─────────────────────────────────────────────

# Minimum number of rooms required for a valid generation
var min_rooms: int = 20

# Hard cap on total rooms
var max_rooms: int = 40

# Probability (1–100) that the walk branches instead of always continuing
var generation_chance: int = 60


# ─────────────────────────────────────────────
# INTERNAL DATA
# ─────────────────────────────────────────────

# The logical grid: maps Vector2i(grid_x, grid_y) → room type string
# Room types: "start", "normal", "boss", "treasure"
var grid: Dictionary = {}

# The four cardinal directions as grid offsets
# Matches your design: N, S, E, W connectivity
const DIRECTIONS = {
	"N": Vector2i(0, -1),
	"S": Vector2i(0,  1),
	"E": Vector2i(1,  0),
	"W": Vector2i(-1, 0)
}


# ─────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────

func _ready():
	# Keep regenerating until we get a valid map (meets min_rooms requirement)
	var success = false
	while not success:
		grid.clear()
		success = _random_walk_logic()
	
	_assign_special_rooms()
	_print_map()


# ─────────────────────────────────────────────
# STEP 1: RANDOM WALK (section 5.4.2 core logic)
# ─────────────────────────────────────────────

func _random_walk_logic() -> bool:
	# Start at origin
	var start_pos = Vector2i(0, 0)
	grid[start_pos] = "start"
	
	# Stack-based walk enables backtracking (as described in your design)
	var stack: Array = [start_pos]
	
	while stack.size() > 0 and grid.size() < max_rooms:
		# Look at the current position on top of the stack
		var current = stack.back()
		
		# Find all neighboring grid cells that are empty (not yet a room)
		var open_neighbors = _get_open_neighbors(current)
		
		if open_neighbors.size() == 0:
			# Dead end — backtrack by popping the stack
			stack.pop_back()
			continue
		
		# Branching chance: only expand if random roll passes
		# This is your generation_chance variable from section 5.4.2
		if randi_range(1, 100) > generation_chance:
			# Failed the roll — backtrack instead of placing a room
			stack.pop_back()
			continue
		
		# Pick a random valid neighbor to expand into
		var next_pos = open_neighbors[randi() % open_neighbors.size()]
		
		# Place a normal room at that position
		grid[next_pos] = "normal"
		
		# Push it onto the stack so we can continue walking from here
		stack.append(next_pos)
	
	# Validate: did we meet the minimum room count?
	return grid.size() >= min_rooms


# ─────────────────────────────────────────────
# STEP 2: ASSIGN BOSS AND TREASURE ROOMS (section 5.4.2 post-processing)
# ─────────────────────────────────────────────

func _assign_special_rooms():
	# Find all dead-end rooms: rooms with only 1 neighbor in the grid
	# (exclude the start room)
	var dead_ends: Array = []
	for pos in grid.keys():
		if grid[pos] == "start":
			continue
		if _count_room_neighbors(pos) == 1:
			dead_ends.append(pos)
	
	if dead_ends.size() == 0:
		return  # No dead ends, nothing to assign
	
	# Boss room = dead end farthest from start (Manhattan distance)
	# As specified in your design: "prioritizes distance from start to maximize player traversal"
	var boss_pos = dead_ends[0]
	var max_dist = 0
	for pos in dead_ends:
		var dist = abs(pos.x) + abs(pos.y)  # Manhattan distance from origin
		if dist > max_dist:
			max_dist = dist
			boss_pos = pos
	grid[boss_pos] = "boss"
	
	# Treasure room = randomly assigned to one of the remaining dead ends
	# As specified: "randomly assigned to any remaining dead-end room"
	dead_ends.erase(boss_pos)
	if dead_ends.size() > 0:
		dead_ends.shuffle()  # Godot's built-in Array.shuffle() — noted in your section 5.4.2
		grid[dead_ends[0]] = "treasure"


# ─────────────────────────────────────────────
# STEP 3: PRINT MAP TO CONSOLE
# ─────────────────────────────────────────────

func _print_map():
	# Find the bounding box of the grid so we know how wide/tall to print
	var min_x = 0
	var max_x = 0
	var min_y = 0
	var max_y = 0
	
	for pos in grid.keys():
		if pos.x < min_x: min_x = pos.x
		if pos.x > max_x: max_x = pos.x
		if pos.y < min_y: min_y = pos.y
		if pos.y > max_y: max_y = pos.y
	
	print("=== DUNGEON MAP ===")
	print("Rooms generated: ", grid.size())
	print("")
	
	# Print row by row (y), column by column (x)
	for y in range(min_y, max_y + 1):
		var row = ""
		for x in range(min_x, max_x + 1):
			var pos = Vector2i(x, y)
			if grid.has(pos):
				var room_type = grid[pos]
				# Notation as specified: [ ] for a room, [*] for start
				match room_type:
					"start":    row += "[*]"   # Starting room marked with *
					"boss":     row += "[B]"   # Boss room
					"treasure": row += "[T]"   # Treasure room
					_:          row += "[ ]"   # Normal room
			else:
				# Empty cell — print spacing to keep alignment
				row += "   "
		print(row)
	
	print("")
	print("Legend: [*]=Start  [ ]=Normal  [B]=Boss  [T]=Treasure")


# ─────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────

# Returns a list of grid positions adjacent to 'pos' that are NOT yet in the grid
func _get_open_neighbors(pos: Vector2i) -> Array:
	var open = []
	for dir in DIRECTIONS.values():
		var neighbor = pos + dir
		if not grid.has(neighbor):
			open.append(neighbor)
	return open


# Returns how many adjacent positions ARE already rooms in the grid
func _count_room_neighbors(pos: Vector2i) -> int:
	var count = 0
	for dir in DIRECTIONS.values():
		if grid.has(pos + dir):
			count += 1
	return count
"""
