extends Node

# ─────────────────────────────────────────────
# CONFIGURATION
# These values control the shape and density of each generated dungeon.
# Tweak them in the Inspector or directly here to adjust feel.
# ─────────────────────────────────────────────

# The minimum number of rooms required before a generated layout is accepted.
# If the random walk produces fewer rooms than this, the whole map is discarded
# and regenerated from scratch.
var min_rooms: int = 5

# Hard ceiling on total rooms. The walk stops expanding once this is hit,
# regardless of how many open neighbors remain.
var max_rooms: int = 10

# Percentage chance (1–100) that the walk continues forward at each step.
# Lower values produce shorter, more fragmented dungeons with lots of backtracking.
# Higher values produce long, sprawling corridors. 60 gives a balanced mix.
var generation_chance: int = 60

# Controls how far the overview camera zooms out to show all rooms.
# Acts as the minimum padding (in world units) added around the room bounding box.
var room_display_radius: float = 1500.0

# ─────────────────────────────────────────────
# ROOM SCENE REFERENCES — assign in Inspector
# Each exported variable holds a .tscn file for a specific corridor shape.
# The generator picks the right scene based on which exits a room needs.
# Keys refer to the sorted exit combination string used in scene_map.
# ─────────────────────────────────────────────

# ── OLD / BASE ROOMS ──
# The starting room — West exit only (player enters from the east side).
@export var scene_start: PackedScene                    # first_room.tscn             key: "West"
# Four-way room — all cardinal exits. Used as fallback for unmatched shapes.
@export var scene_all_dirs: PackedScene                 # tri_connectl_lud.tscn        key: "East_North_South_West"
# Horizontal corridor — East and West exits only.
@export var scene_lr: PackedScene                       # lr_connector.tscn            key: "East_West" (variant 1)
# Vertical corridor — North and South exits only.
@export var scene_ud: PackedScene                       # ud_hall_way.tscn             key: "North_South"

# ── NEW DEAD-END ROOMS ──
# Dead end with a single South exit (opens downward).
@export var scene_up_deadend: PackedScene               # up_deadend.tscn              key: "South"
# Dead end with a single North exit (opens upward).
@export var scene_down_deadend: PackedScene             # down_deadend.tscn            key: "North"
# Dead end with a single West exit — variant 1.
@export var scene_right_deadend: PackedScene            # right_deadend.tscn           key: "West" (variant 2)
# Dead end with a single East exit — variant 1.
@export var scene_left_dead_end: PackedScene            # left_dead_end.tscn           key: "East" (variant 1)
# Dead end with a single East exit — variant 2.
@export var scene_left_dead_end2: PackedScene           # left_dead_end2.tscn          key: "East" (variant 2)
# Dedicated boss room — West exit only (same key as start/right_deadend but reserved for boss).
@export var scene_boss_room: PackedScene                # boss_room.tscn               key: "West" (boss variant)

# ── NEW CORNER ROOMS ──
# Corner room with North and West exits — variant 1.
@export var scene_left_up_room2: PackedScene            # left_up_room2.tscn           key: "North_West" (variant 1)         # right_up_room.tscn           key: "North_West" (variant 1)
# Corner room with North and West exits — variant 2.
@export var scene_left_up_room: PackedScene             # left_up_room.tscn            key: "North_West" (variant 2)
# Corner room with East and South exits.
@export var scene_right_down_room: PackedScene          # right_down_room.tscn         key: "East_South"
# Corner room with West and South exits.
@export var scene_left_down_room: PackedScene           # left_down_room.tscn          key: "West_South"


# ── NEW CORRIDOR / MULTI-EXIT ROOMS ──
# Horizontal-style corridor — East and West exits, variant 2.
@export var scene_right_up_doown_groovin: PackedScene   # right_up_doown_groovin.tscn  key: "East_West" (variant 2)
# Three-way room — East, South, and West exits.
@export var scene_left_right_down_trololol: PackedScene # left_right_down_trololol.tscn key: "East_South_West"
# Three-way room — North, South, and West exits — variant 1.
@export var scene_left_up_down_cave1: PackedScene       # left_up_down_cave1.tscn      key: "North_South_West" (variant 1)
# Three-way room — North, South, and West exits — variant 2.
@export var scene_left_up_down_cave_2: PackedScene      # left_up_down_cave_2.tscn     key: "North_South_West" (variant 2)
# Three-way room — North, East, and West exits.
@export var scene_left_right_up_67: PackedScene         # left_right_up_67.tscn        key: "North_East_West"
# Four-way room — all cardinal exits, variant 2.
@export var scene_left_right_up_down_loss: PackedScene  # left_right_up_down_loss.tscn key: "East_North_South_West" (variant 2)

# ── NEW ROOMS ──
# Three-way room — East, North, and South exits.
@export var scene_up_down_right_groovin: PackedScene    # up_down_right_groovin.tscn   key: "East_North_South"
# Corner room — East and North exits.
@export var scene_right_up_room2: PackedScene           # right_up_room2.tscn          key: "East_North"
# Boss room variant — South exit only.
@export var scene_boss_room4: PackedScene               # boss_room4.tscn              key: "South" (boss variant)
# Boss room variant — North exit only.
@export var scene_boss_room3: PackedScene               # boss_room3.tscn              key: "North" (boss variant)
# Boss room variant — East exit only.
@export var scene_boss_room2: PackedScene               # boss_room2.tscn              key: "East" (boss variant)

# ── TREASURE ROOM VARIANTS ──
# Treasure rooms are always dead ends — one variant per approach direction.
# The treasure room picker selects based on which single exit the grid position needs.
# Treasure room approached from the East (player enters from East, room opens West).
@export var scene_treasure: PackedScene                 # treasure.tscn                key: "West" (treasure variant)
# Treasure room approached from the West (player enters from West, room opens East).
@export var scene_treasure2: PackedScene                # treasure.tscn2               key: "East" (treasure variant)
# Treasure room approached from the North (player enters from North, room opens South).
@export var scene_treasure3: PackedScene                # treasure.tscn3               key: "South" (treasure variant)
# Treasure room approached from the South (player enters from South, room opens North).
@export var scene_treasure4: PackedScene                # treasure.tscn4               key: "North" (treasure variant)

# ─────────────────────────────────────────────
# ENEMY SCENES — assign in Inspector
# ─────────────────────────────────────────────

@export var enemy_scenes: Array[PackedScene] = []
# Dedicated boss enemy. If set, this is the ONLY enemy spawned in boss rooms.
@export var boss_enemy_scene: PackedScene
@export var min_enemies_per_room: int = 1
@export var max_enemies_per_room: int = 3

# How far enemies scatter around their spawn marker (pixels)
@export var spawn_scatter_radius: float = 80.0
signal dungeon_ready
signal room_changed(room_type: String)
# TRANSITION EDIT
var current_room_pos: Vector2i = Vector2i(0, 0)
var is_transitioning: bool = false

# ─────────────────────────────────────────────
# INTERNAL DATA
# These dictionaries are the core runtime state of the generator.
# ─────────────────────────────────────────────

# The logical grid: maps a grid-space Vector2i coordinate → room type string.
# Room types are: "start", "normal", "boss", "treasure".
# This is populated by the random walk and is the source of truth for layout.
var grid: Dictionary = {}

# Maps grid coordinates → instantiated room Node2D objects already added to the scene.
# Used during placement so rooms can snap to each other via their exit markers.
var placed_rooms: Dictionary = {}
var player_spawn_pos: Vector2 = Vector2.ZERO

# The four cardinal directions expressed as grid-space offsets.
# "North" moves one cell up (y − 1) in grid space (screen y is inverted in Godot).
const DIRECTIONS = {
	"North": Vector2i(0, -1),
	"South": Vector2i(0,  1),
	"East":  Vector2i(1,  0),
	"West":  Vector2i(-1, 0)
}

# Maps each direction to the direction directly opposite to it.
# Used when checking whether a neighbor's exit aligns with our entry.
const OPPOSITE = {
	"North": "South",
	"South": "North",
	"East":  "West",
	"West":  "East"
}

# Maps a scene key string (like "East_West") → its PackedScene resource.
# Populated in _ready() after the @export variables are set by the Inspector.
var scene_map: Dictionary = {}

# Declares which exit directions each scene key supports.
# Keys are sorted, underscore-joined strings of exit direction names.
# Used by the walk to verify a neighbor can connect back before expanding.
# Every unique combination across old and new rooms is listed here.
var scene_exits: Dictionary = {
	"North":                 ["North"],
	"South":                 ["South"],
	"East":                  ["East"],
	"West":                  ["West"],
	"East_North":            ["East", "North"],
	"East_South":            ["East", "South"],
	"East_West":             ["East", "West"],
	"North_South":           ["North", "South"],
	"North_West":            ["North", "West"],
	"West_South":            ["South", "West"],
	"East_North_South":      ["East", "North", "South"],
	"East_South_West":       ["East", "South", "West"],
	"North_East_West":       ["East", "North", "West"],
	"North_South_West":      ["North", "South", "West"],
	"East_North_South_West": ["East", "North", "South", "West"]
}

# ─────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────
func _ready():
	print("\n============================================================")
	print("DUNGEON GENERATOR STARTING")
	print("============================================================")
	
	# Wire up the scene_map now that @export references are available.
	# Each key matches a possible _get_connection_key() result so _pick_best_scene()
	# can look up the right PackedScene directly.

	# ── Single-scene keys — one exact scene per combination ──
	scene_map["North_South"]      = scene_ud
	scene_map["East_South"]       = scene_right_down_room
	scene_map["North_East_West"]  = scene_left_right_up_67
	scene_map["West_South"]       = scene_left_down_room
	scene_map["East_North"]       = scene_right_up_room2
	scene_map["East_North_South"] = scene_up_down_right_groovin
	scene_map["East_South_West"]  = scene_left_right_down_trololol

	# ── Multi-variant keys — multiple scenes share the same exit combination.
	# _pick_best_scene() will randomly select from the pool each time,
	# giving visual variety across runs without any extra logic at the call site.
	# Each pool is stored as an Array under the same key used by _get_connection_key().
	scene_map["West"]                  = [scene_start, scene_right_deadend] # boss_room/treasure handled via boss override
	scene_map["East"]                  = [scene_left_dead_end, scene_left_dead_end2] # boss_room2/treasure handled via boss override
	scene_map["North"]                 = [scene_down_deadend] # boss_room3/treasure handled via boss override
	scene_map["South"]                 = [scene_up_deadend] # boss_room4/treasure handled via boss override
	scene_map["North_West"]            = [scene_right_up_room2, scene_left_up_room]
	scene_map["East_West"]             = [scene_lr, scene_right_up_doown_groovin]
	scene_map["North_South_West"]      = [scene_left_up_down_cave1, scene_left_up_down_cave_2]
	scene_map["East_North_South_West"] = [scene_all_dirs, scene_left_right_up_down_loss]
	

	# Keep regenerating until a valid layout is produced.
	# "Valid" means: enough rooms AND at least two dead ends for boss/treasure.
	var success = false
	while not success:
		grid.clear()
		placed_rooms.clear()

		# Remove all previously instantiated room nodes (skip the camera).
		for child in get_children():
			child.queue_free()

		success = _random_walk_logic()

	# Post-process the logical grid to label boss and treasure rooms.
	_assign_special_rooms()

	# Print an ASCII map to the Output panel for quick debugging.
	_print_map()
	call_deferred("_place_rooms")


## Called by game_manager to know where to put the player
func get_player_spawn_position() -> Vector2:
	return player_spawn_pos


# ─────────────────────────────────────────────
# STEP 1: RANDOM WALK
# Builds the logical grid (grid coordinates only — no scene nodes yet).
# Uses a stack to support backtracking when a branch dead-ends.
# Returns true if the resulting layout meets all validity requirements.
# ─────────────────────────────────────────────
func _random_walk_logic() -> bool:
	var start_pos = Vector2i(0, 0)
	grid[start_pos] = "start"

	# The stack drives the walk. We always look at the top (back) of the stack.
	# Pushing a new position means "continue the walk from here."
	# Popping means "backtrack — this branch has nowhere left to go."
	var stack: Array = [start_pos]

	while stack.size() > 0 and grid.size() < max_rooms:
		var current = stack.back()

		# Find all adjacent grid cells that are empty AND reachable
		# (i.e. some scene exists that can provide the required connecting exit).
		var open_neighbors = _get_valid_open_neighbors(current)

		if open_neighbors.size() == 0:
			# No valid empty neighbors — this cell is a dead end. Backtrack.
			stack.pop_back()
			continue

		# generation_chance controls how often the walk continues vs. backtracks.
		# Rolling above the threshold forces a backtrack even when expansion is possible,
		# which is what creates branching paths instead of one long straight corridor.
		if randi_range(1, 100) > generation_chance:
			stack.pop_back()
			continue

		# Pick a random valid neighbor and claim it as a new room.
		var next_pos = open_neighbors[randi() % open_neighbors.size()]
		grid[next_pos] = "normal"

		# Push the new position so the walk continues from there next iteration.
		stack.append(next_pos)

	# Reject layouts that are too small — they wouldn't make a fun dungeon.
	if grid.size() < min_rooms:
		return false

	# Count dead ends (rooms with exactly 1 neighbor), excluding the start room.
	# We need at least 2: one will become the boss room, one the treasure room.
	var dead_end_count = 0
	for pos in grid.keys():
		if grid[pos] == "start":
			continue
		if _count_room_neighbors(pos) == 1:
			dead_end_count += 1

	if dead_end_count < 2:
		return false

	return true


# Returns all adjacent empty grid positions that the walk is ALLOWED to expand into
# from the given position. A neighbor is valid only if:
#   1. Its cell is not already occupied in the grid.
#   2. Some available scene can provide an exit pointing back toward the current cell.
# This prevents the walk from creating connections that no room scene can satisfy.
func _get_valid_open_neighbors(pos: Vector2i) -> Array:
	var open = []

	# Ask which directions this position is even allowed to exit toward.
	var current_possible_exits = _get_possible_exits_for_pos(pos)

	for dir_name in current_possible_exits:
		var neighbor = pos + DIRECTIONS[dir_name]

		# Skip if the neighbor cell is already a room.
		if grid.has(neighbor):
			continue

		# The neighbor would need an exit pointing back toward us (the opposite direction).
		# Only allow expansion if at least one scene can provide that return exit.
		var return_dir = OPPOSITE[dir_name]
		if not _any_scene_has_exit(return_dir):
			continue

		open.append(neighbor)
	return open


# Returns which directions the given position is allowed to expand toward.
# The start room (0,0) is restricted to West-only because scene_start only has a West exit.
# All other rooms can potentially expand in any direction that some scene supports.
func _get_possible_exits_for_pos(pos: Vector2i) -> Array:
	if pos == Vector2i(0, 0):
		# The start room's exits are fixed by its scene definition — West only.
		return scene_exits.get("West", [])

	# For all other rooms, any direction is fair game as long as a scene supports it.
	var possible = []
	for dir_name in DIRECTIONS.keys():
		if _any_scene_has_exit(dir_name):
			possible.append(dir_name)
	return possible


# Returns true if ANY registered scene provides an exit in the given direction.
# Used to filter out directions that would be structurally impossible to fulfill.
func _any_scene_has_exit(dir_name: String) -> bool:
	for key in scene_exits.keys():
		if dir_name in scene_exits[key]:
			return true
	return false


# ─────────────────────────────────────────────
# STEP 2: SPECIAL ROOM ASSIGNMENT
# Runs after the random walk to label two dead-end rooms with special roles.
# Dead ends are rooms with only one grid neighbor — they sit at the tips of branches.
# ─────────────────────────────────────────────
func _assign_special_rooms():
	# Collect all dead-end positions, ignoring the start room.
	var dead_ends: Array = []
	for pos in grid.keys():
		if grid[pos] == "start":
			continue
		if _count_room_neighbors(pos) == 1:
			dead_ends.append(pos)

	if dead_ends.size() == 0:
		return

	# Boss room = the dead end with the greatest Manhattan distance from the origin.
	# Placing the boss as far from the start as possible maximizes required traversal,
	# so the player has to explore more of the dungeon to reach it.
	var boss_pos = dead_ends[0]
	var max_dist = 0
	for pos in dead_ends:
		var dist = abs(pos.x) + abs(pos.y)
		if dist > max_dist:
			max_dist = dist
			boss_pos = pos

	grid[boss_pos] = "boss"
	dead_ends.erase(boss_pos)

	# Treasure room = randomly chosen from the remaining dead ends.
	# Randomness here keeps the treasure location unpredictable across runs.
	if dead_ends.size() > 0:
		dead_ends.shuffle()
		grid[dead_ends[0]] = "treasure"


# ─────────────────────────────────────────────
# STEP 3: PLACE ROOMS
# Translates the logical grid into actual Node2D instances in world space.
# Uses a BFS queue so every room is placed only after at least one of its
# grid neighbors has already been placed (guaranteeing a valid anchor exists).
# ─────────────────────────────────────────────
func _place_rooms():
	# BFS starting from the origin ensures we always place a room's neighbor
	# before or shortly after the room itself, so _calculate_position() can
	# find the anchor it needs within a small number of retries.
	var visit_queue: Array = [Vector2i(0, 0)]
	var visited: Dictionary = {}

	# Tracks how many times placement has been retried for each grid position.
	# Prevents an infinite loop if a room genuinely has no placed neighbor yet.
	var retry_count: Dictionary = {}

	while visit_queue.size() > 0:
		var grid_pos = visit_queue.pop_front()

		# Skip positions we've already successfully placed (or given up on).
		if visited.has(grid_pos):
			continue

		# Determine which exits this room needs based on its grid neighbors.
		var exits = _get_exits_for_pos(grid_pos)

		# Convert the exit list to a sorted, underscore-joined key for scene lookup.
		var key = _get_connection_key(exits)

		# Choose the appropriate PackedScene for this room's connection shape.
		var packed: PackedScene
		if grid_pos == Vector2i(0, 0):
			# The start room always uses its dedicated scene, regardless of computed exits.
			packed = scene_start
		elif grid[grid_pos] == "boss":
			# Boss rooms use a dedicated scene matched to their exit direction.
			# Each boss variant covers one dead-end direction so snapping works correctly.
			# Falls back to _pick_best_scene if no boss variant is assigned for this key.
			var boss_packed = _pick_boss_scene(key)
			packed = boss_packed if boss_packed != null else _pick_best_scene(key, exits)
		elif grid[grid_pos] == "treasure":
			# Treasure rooms use a dedicated scene matched to their exit direction.
			# Each treasure variant covers one dead-end direction so snapping works correctly.
			# Falls back to _pick_best_scene if no treasure variant is assigned for this key.
			var treasure_packed = _pick_treasure_scene(key)
			packed = treasure_packed if treasure_packed != null else _pick_best_scene(key, exits)
		else:
			packed = _pick_best_scene(key, exits)

		if packed == null:
			# No scene exists for this shape — skip silently rather than crashing.
			print("INFO: Skipping room at ", grid_pos,
				" — no valid scene for key '", key, "'")
			visited[grid_pos] = true
			continue

		# Instantiate the scene so we can query its exit marker positions.
		var room_instance = packed.instantiate()

		if grid_pos == Vector2i(0, 0):
			# The start room is the anchor for the entire dungeon — place it at the world origin.
			room_instance.position = Vector2.ZERO
			add_child(room_instance)
			print("Room at [0,0] (START): instantiated at ", room_instance.position)
		else:
			# Calculate the world position by snapping this room's entry marker
			# to the matching exit marker of an already-placed neighbor.
			var snapped_pos = _calculate_position(grid_pos, room_instance)

			if snapped_pos == null:
				# No placed neighbor found yet — free the instance and try again later.
				room_instance.free()
				retry_count[grid_pos] = retry_count.get(grid_pos, 0) + 1

				if retry_count[grid_pos] < 20:
					# Re-queue the room at the back so its neighbors can be placed first.
					visit_queue.append(grid_pos)
				else:
					# Give up after 20 retries to avoid an infinite loop.
					print("WARNING: Giving up on room at ", grid_pos,
						" — no anchor found after retries")
					visited[grid_pos] = true
				continue

			# Anchor found — add to the scene and snap into position.
			room_instance.position = snapped_pos
			add_child(room_instance)
			print("Room at ", grid_pos, " (", grid[grid_pos], "): instantiated at ", room_instance.position)

		# Mark this grid position as done and register the instance for future anchoring.
		visited[grid_pos] = true
		placed_rooms[grid_pos] = room_instance

		# Store grid metadata directly on the node for other systems to query at runtime.
		room_instance.set_meta("grid_pos", grid_pos)
		room_instance.set_meta("room_type", grid[grid_pos])

		# Queue all unvisited grid neighbors for placement.
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
	#call_deferred("_spawn_boundary")
	Autoload.dungeon_generator = self
	# TRANSITION EDIT
	call_deferred("_setup_room_system")


# ─────────────────────────────────────────────
# STEP 4: SPAWN ENEMIES (WITH MARGIN FIX)
# ─────────────────────────────────────────────

# CORRECTED _spawn_enemies() FUNCTION
# Replace your entire _spawn_enemies() function with this:

func _spawn_enemies() -> void:
	if enemy_scenes.size() == 0 and boss_enemy_scene == null:
		return

	for grid_pos in placed_rooms.keys():
		var room_type = grid[grid_pos]

		# No enemies in start or treasure rooms
		if room_type in ["start", "treasure"]:
			continue

		var room = placed_rooms[grid_pos]
		var is_boss: bool = (room_type == "boss")

		# Collect spawn points from EnemySpawns markers, fallback to room center
		var spawn_points: Array = []
		var spawns_container = room.find_child("EnemySpawns", true, false)
		if spawns_container:
			for child in spawns_container.get_children():
				if child is Marker2D:
					spawn_points.append(child.global_position)
		if spawn_points.size() == 0:
			spawn_points.append(room.global_position)

		# Boss room: spawn exactly one boss, skip the normal pool.
		if is_boss:
			if boss_enemy_scene == null:
				continue
			var boss = boss_enemy_scene.instantiate()
			room.add_child(boss)
			if boss.has_method("setup"):
				boss.setup(spawn_points[0])
			else:
				boss.global_position = spawn_points[0]
			continue

		# Normal rooms: pull from enemy_scenes pool, one per spawn point up to max.
		if enemy_scenes.size() == 0:
			continue

		var enemy_count: int = mini(
			randi_range(min_enemies_per_room, max_enemies_per_room),
			spawn_points.size()
		)

		spawn_points.shuffle()

		for i in enemy_count:
			var base: Vector2 = spawn_points[i]
			var enemy_scene = enemy_scenes[randi() % enemy_scenes.size()]
			var enemy = enemy_scene.instantiate()
			room.add_child(enemy)
			if enemy.has_method("setup"):
				enemy.setup(base)
			else:
				enemy.global_position = base
				
# Computes the world-space position for a new room by snapping its entry marker
# to the exit marker of the nearest already-placed neighbor.
#
# The key insight: if the new room is EAST of a placed neighbor, then:
#   - The neighbor's exit pointing toward us is its "East" exit.
#   - Our entry pointing toward the neighbor is our "West" exit.
# So we translate our origin so that our West marker lands exactly on
# the neighbor's East marker.
func _calculate_position(grid_pos: Vector2i, new_instance: Node2D) -> Variant:
	for dir_name in DIRECTIONS.keys():
		# dir_name is the direction FROM the new room TO this potential neighbor.
		var neighbor_grid_pos = grid_pos + DIRECTIONS[dir_name]

		# Only use neighbors that have already been placed in world space.
		if not placed_rooms.has(neighbor_grid_pos):
			continue

		var placed_neighbor = placed_rooms[neighbor_grid_pos]

		# The neighbor's exit faces TOWARD us — that's the OPPOSITE of dir_name.
		# Our entry faces TOWARD the neighbor — that's dir_name itself.
		var neighbor_exit_name = "Exit" + OPPOSITE[dir_name]
		var our_entry_name     = "Exit" + dir_name

		# Look up the marker nodes by name inside each scene instance.
		var neighbor_marker = placed_neighbor.find_child(neighbor_exit_name, true, false)
		var our_marker      = new_instance.find_child(our_entry_name, true, false)

		# If either marker is missing (scene mismatch or naming error), try another neighbor.
		if neighbor_marker == null or our_marker == null:
			continue

		# Snap formula: place the new room so its entry marker aligns with the neighbor's exit marker.
		# new_room.position + our_marker.position == placed_neighbor.position + neighbor_marker.position
		# → new_room.position = placed_neighbor.position + neighbor_marker.position - our_marker.position
		return placed_neighbor.position + neighbor_marker.position - our_marker.position

	# No placed neighbor with matching markers found yet — caller should retry.
	return null


# ─────────────────────────────────────────────
# BOUNDARY WALLS
# Builds a tight collision border around each room's floor area so the
# player and enemies cannot walk into the void between or outside rooms.
# Reads each room's floor TileMapLayer used_rect for exact floor bounds,
# then spawns thin StaticBody2D walls on all four sides — leaving gaps
# only at exit corridors that connect to adjacent placed rooms.
# ─────────────────────────────────────────────

func _spawn_boundary() -> void:
	if placed_rooms.size() == 0:
		return

	var thick: float = 64.0   # wall thickness (pixels)
	var gap: float   = 160.0  # half-width of the opening left at each exit corridor

	for grid_pos in placed_rooms.keys():
		var room: Node2D = placed_rooms[grid_pos]

		# Find the floor TileMapLayer (named "floor" in all room scenes)
		var floor_layer = room.find_child("floor", true, false)
		if floor_layer == null:
			floor_layer = room.find_child("Floor", true, false)
		if floor_layer == null or not floor_layer is TileMapLayer:
			continue

		# get_used_rect() returns tile-space Rect2i.
		# Multiply by tile_size to convert to local pixel coords.
		var tile_size: Vector2 = Vector2(floor_layer.tile_set.tile_size)
		var used: Rect2i = floor_layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue

		var local_min: Vector2 = Vector2(used.position) * tile_size
		var local_max: Vector2 = Vector2(used.position + used.size) * tile_size

		# Convert to world coords
		var wmin: Vector2 = room.global_position + local_min
		var wmax: Vector2 = room.global_position + local_max
		var w: float = wmax.x - wmin.x
		var h: float = wmax.y - wmin.y
		var cx: float = (wmin.x + wmax.x) * 0.5
		var cy: float = (wmin.y + wmax.y) * 0.5

		# Which directions connect to another placed room?
		var exits: Dictionary = {}
		for dir_name in DIRECTIONS.keys():
			if placed_rooms.has(grid_pos + DIRECTIONS[dir_name]):
				exits[dir_name] = true

		# TOP — full wall or two halves around the North exit gap
		if not exits.has("North"):
			_add_wall(Vector2(cx, wmin.y - thick * 0.5), Vector2(w + thick * 2.0, thick))
		else:
			var em = room.find_child("ExitNorth", true, false)
			var ex: float = em.global_position.x if em else cx
			_add_wall(Vector2((wmin.x + (ex - gap)) * 0.5, wmin.y - thick * 0.5),
					Vector2(maxf(ex - gap - wmin.x, 0.0) + thick, thick))
			_add_wall(Vector2(((ex + gap) + wmax.x) * 0.5, wmin.y - thick * 0.5),
					Vector2(maxf(wmax.x - (ex + gap), 0.0) + thick, thick))

		# BOTTOM — full wall or two halves around the South exit gap
		if not exits.has("South"):
			_add_wall(Vector2(cx, wmax.y + thick * 0.5), Vector2(w + thick * 2.0, thick))
		else:
			var em = room.find_child("ExitSouth", true, false)
			var ex: float = em.global_position.x if em else cx
			_add_wall(Vector2((wmin.x + (ex - gap)) * 0.5, wmax.y + thick * 0.5),
					Vector2(maxf(ex - gap - wmin.x, 0.0) + thick, thick))
			_add_wall(Vector2(((ex + gap) + wmax.x) * 0.5, wmax.y + thick * 0.5),
					Vector2(maxf(wmax.x - (ex + gap), 0.0) + thick, thick))

		# LEFT — full wall or two halves around the West exit gap
		if not exits.has("West"):
			_add_wall(Vector2(wmin.x - thick * 0.5, cy), Vector2(thick, h + thick * 2.0))
		else:
			var em = room.find_child("ExitWest", true, false)
			var ey: float = em.global_position.y if em else cy
			_add_wall(Vector2(wmin.x - thick * 0.5, (wmin.y + (ey - gap)) * 0.5),
					Vector2(thick, maxf(ey - gap - wmin.y, 0.0) + thick))
			_add_wall(Vector2(wmin.x - thick * 0.5, ((ey + gap) + wmax.y) * 0.5),
					Vector2(thick, maxf(wmax.y - (ey + gap), 0.0) + thick))

		# RIGHT — full wall or two halves around the East exit gap
		if not exits.has("East"):
			_add_wall(Vector2(wmax.x + thick * 0.5, cy), Vector2(thick, h + thick * 2.0))
		else:
			var em = room.find_child("ExitEast", true, false)
			var ey: float = em.global_position.y if em else cy
			_add_wall(Vector2(wmax.x + thick * 0.5, (wmin.y + (ey - gap)) * 0.5),
					Vector2(thick, maxf(ey - gap - wmin.y, 0.0) + thick))
			_add_wall(Vector2(wmax.x + thick * 0.5, ((ey + gap) + wmax.y) * 0.5),
					Vector2(thick, maxf(wmax.y - (ey + gap), 0.0) + thick))


func _add_wall(center: Vector2, size: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = 1  # world layer — same as tilemap walls
	body.collision_mask  = 0
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
	body.global_position = center


func _setup_overview_camera():
	if placed_rooms.size() == 0:
		return

	# Locate the pre-existing OverviewCamera node in the scene tree.
	var cam = get_node_or_null("OverviewCamera")
	if cam == null:
		print("ERROR: OverviewCamera node not found")
		return

	# Compute the world-space bounding box of all placed rooms.
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

	# Pad the bounding box so edge rooms aren't clipped at the screen border.
	# The padding is 30% of each axis span, or room_display_radius — whichever is larger.
	# This keeps both tall/narrow and wide/short dungeons well-framed.
	var x_span = max_x - min_x
	var y_span = max_y - min_y
	var x_pad = max(x_span * 0.3, room_display_radius)
	var y_pad = max(y_span * 0.3, room_display_radius)

	min_x -= x_pad
	max_x += x_pad
	min_y -= y_pad
	max_y += y_pad

	# Center the camera on the padded bounding box.
	var center = Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)
	cam.position = center
	cam.make_current()

	# Compute zoom so the full padded bounding box fits in the viewport.
	# Use the more restrictive axis (smaller zoom) so nothing gets cut off.
	# Multiply by 0.6 to leave a small additional margin around the edges.
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom_x = viewport_size.x / (max_x - min_x)
	var zoom_y = viewport_size.y / (max_y - min_y)
	var zoom_level = min(zoom_x, zoom_y) * 0.6
	cam.zoom = Vector2(zoom_level, zoom_level)


# ─────────────────────────────────────────────
# STEP 5: CONSOLE PRINT
# Renders an ASCII overview of the logical grid to the Output panel.
# Purely a debugging aid — does not affect any game state.
# ─────────────────────────────────────────────
func _print_map():
	# Find the axis-aligned bounding box of all grid positions.
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

	# Iterate row-by-row (y), then column-by-column (x) to print a 2D grid.
	for y in range(min_y, max_y + 1):
		var row = ""
		for x in range(min_x, max_x + 1):
			var pos = Vector2i(x, y)
			if grid.has(pos):
				# Use distinct symbols to visually distinguish each room role.
				match grid[pos]:
					"start":    row += "[*]"    # Starting room
					"boss":     row += "[B]"    # Boss room (farthest dead end)
					"treasure": row += "[T]"    # Treasure room (random dead end)
					_:          row += "[ ]"    # Normal room
			else:
				# Empty cell — three spaces to match the width of "[X]".
				row += "   "
		print(row)

	print("")
	print("Legend: [*]=Start  [ ]=Normal  [B]=Boss  [T]=Treasure")
	print("------------------------------------------------------------\n")


# ─────────────────────────────────────────────
# HELPERS
# Small, single-purpose functions that keep the steps above readable.
# ─────────────────────────────────────────────

# Selects a PackedScene for a room based on its connection key.
# scene_map values may be a single PackedScene OR an Array of PackedScenes
# (for keys where multiple room variants share the same exit combination).
# When multiple variants exist, one is chosen randomly for visual variety.
# If no exact match exists, falls back to the all-directions scene pool.
func _pick_best_scene(key: String, exits: Array) -> PackedScene:
	if scene_map.has(key):
		var entry = scene_map[key]
		# If it's an Array, pick a random variant from the pool
		if entry is Array and entry.size() > 0:
			return entry[randi() % entry.size()]
		# Otherwise it's a direct PackedScene reference
		if entry is PackedScene:
			return entry
	# No exact match — fall back to the all-directions pool
	if scene_map.has("East_North_South_West"):
		var fallback = scene_map["East_North_South_West"]
		if fallback is Array and fallback.size() > 0:
			return fallback[randi() % fallback.size()]
		if fallback is PackedScene:
			return fallback
	return null
	

# Returns the appropriate boss room scene for a given connection key.
# Boss rooms are always dead ends so keys will always be single-direction.
# Returns null if no boss variant is assigned for that direction — caller falls back
# to normal scene selection in that case.
func _pick_boss_scene(key: String) -> PackedScene:
	match key:
		"West":  return scene_boss_room   # boss_room.tscn
		"South": return scene_boss_room4  # boss_room4.tscn
		"North": return scene_boss_room3  # boss_room3.tscn
		"East":  return scene_boss_room2  # boss_room2.tscn
	return null
	
# Returns the appropriate treasure room scene for a given connection key.
# Treasure rooms are always dead ends so keys will always be single-direction.
# Returns null if no treasure variant is assigned for that direction — caller falls back
# to normal scene selection in that case.
func _pick_treasure_scene(key: String) -> PackedScene:
	match key:
		"West":  return scene_treasure    # treasure.tscn
		"East":  return scene_treasure2   # treasure.tscn2
		"South": return scene_treasure3   # treasure.tscn3
		"North": return scene_treasure4   # treasure.tscn4
	return null

# Returns which directions from grid_pos lead to another occupied grid cell.
# This directly represents which exits the room at that position must have.
func _get_exits_for_pos(pos: Vector2i) -> Array:
	var exits = []
	for dir_name in DIRECTIONS.keys():
		if grid.has(pos + DIRECTIONS[dir_name]):
			exits.append(dir_name)
	return exits


# Converts a list of exit direction names into a canonical string key
# by sorting alphabetically and joining with underscores.
# Example: ["West", "East"] → "East_West"
# Sorting ensures the key is consistent regardless of iteration order.
func _get_connection_key(exits: Array) -> String:
	var sorted = exits.duplicate()
	sorted.sort()
	return "_".join(sorted)


# Returns the number of grid neighbors that are occupied rooms.
# Used to identify dead ends (count == 1) for boss/treasure assignment.
func _count_room_neighbors(pos: Vector2i) -> int:
	var count = 0
	for dir in DIRECTIONS.values():
		if grid.has(pos + dir):
			count += 1
	return count

# ─────────────────────────────────────────────
# ROOM VISIBILITY + EXIT TRIGGERS
# ─────────────────────────────────────────────
# TRANSITION EDIT
func _setup_room_system() -> void:
	# Hide all rooms except the start room
	for grid_pos in placed_rooms.keys():
		_set_room_active(placed_rooms[grid_pos], grid_pos == Vector2i(0, 0))
		#placed_rooms[grid_pos].visible = (grid_pos == Vector2i(0, 0))
	
	# Spawn exit triggers on every placed room
	for grid_pos in placed_rooms.keys():
		_add_exit_triggers(grid_pos)
	
	# Disable the overview camera — player camera takes over
	var overview_cam = get_node_or_null("OverviewCamera")
	if overview_cam:
		overview_cam.enabled = false
	
	print("Room system ready. Start room visible, all triggers placed.")
	emit_signal("dungeon_ready")
	var minimap = get_tree().get_first_node_in_group("minimap")
	if minimap:
		minimap.on_dungeon_loaded()



# TRANSITION EDIT

func _add_exit_triggers(grid_pos: Vector2i) -> void:
	var room = placed_rooms[grid_pos]
	
	for dir_name in DIRECTIONS.keys():
		var neighbor_pos = grid_pos + DIRECTIONS[dir_name]
		
		# Only add a trigger if there's actually a room on the other side
		if not placed_rooms.has(neighbor_pos):
			continue
		
		# Only add if the exit marker exists in this room scene
		var marker = room.find_child("Exit" + dir_name, true, false)
		if marker == null:
			continue
		
		var trigger = Area2D.new()
		trigger.name = "ExitTrigger_" + dir_name
		trigger.collision_layer = 0
		trigger.collision_mask = 2  # layer 2 = player (matches your MainChar collision_layer)
		
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		# Wide flat zone — tall for E/W exits, wide for N/S exits
		rect.size = Vector2(32, 160) if dir_name in ["East", "West"] else Vector2(160, 32)
		shape.shape = rect
		trigger.add_child(shape)
		room.add_child(trigger)
		trigger.global_position = marker.global_position
		match dir_name:
			"North":
				trigger.global_position = Vector2(marker.global_position.x, marker.global_position.y+30)
			"East":
				trigger.global_position = Vector2(marker.global_position.x-30, marker.global_position.y)
			"South":
				trigger.global_position = Vector2(marker.global_position.x, marker.global_position.y-30)
			"West":
				trigger.global_position = Vector2(marker.global_position.x+30, marker.global_position.y)
		
		trigger.set_meta("from_grid", grid_pos)
		trigger.set_meta("to_grid", neighbor_pos)
		trigger.set_meta("direction", dir_name)
		print("  Trigger added: ", dir_name, " at ", marker.global_position, " mask=", trigger.collision_mask)
		trigger.body_entered.connect(_on_exit_triggered.bind(trigger))


# TRANSITION EDIT

func _on_exit_triggered(body: Node2D, trigger: Area2D) -> void:
	print("EXIT TRIGGER FIRED — body: ", body.name, " groups: ", body.get_groups())
	if is_transitioning:
		print("  → blocked: already transitioning")
		return
	if not body.is_in_group("player"):
		print("  → blocked: not in player group")
		return
	var to_grid: Vector2i = trigger.get_meta("to_grid")
	var direction: String = trigger.get_meta("direction")
	print("  → transitioning to ", to_grid, " via ", direction)
	is_transitioning = true
	_transition_to_room(to_grid, direction)


func _transition_to_room(to_grid: Vector2i, came_from_direction: String) -> void:
	#is_transitioning = true
	var player = Autoload.main_char
	var overlay = _get_or_create_overlay()
	
	# Fade out
	var tween_out = create_tween()
	tween_out.tween_property(overlay, "color:a", 1.0, 0.35)
	await tween_out.finished
	
	## Swap room visibility
	#placed_rooms[current_room_pos].visible = false
	#var new_room = placed_rooms[to_grid]
	#new_room.visible = true
	# Swap rooms — deactivate old, activate new
	_set_room_active(placed_rooms[current_room_pos], false)
	var new_room = placed_rooms[to_grid]
	_set_room_active(new_room, true)
	
	# Reposition player at the entry side of the new room
	var entry_dir = OPPOSITE[came_from_direction]
	var entry_marker = new_room.find_child("Exit" + entry_dir, true, false)
	
	if entry_marker:
		var inward = Vector2.ZERO
		match entry_dir:
			"East":  inward = Vector2(-50, 0)
			"West":  inward = Vector2(50, 0)
			"North": inward = Vector2(0, 50)
			"South": inward = Vector2(0, -50)
		player.global_position = entry_marker.global_position + inward
	else:
		player.global_position = new_room.global_position
	
	current_room_pos = to_grid
	var room_type: String = grid.get(to_grid, "normal")
	emit_signal("room_changed", room_type)
	
		# Fade back in
	var tween_in = create_tween()
	tween_in.tween_property(overlay, "color:a", 0.0, 0.35)
	await tween_in.finished
	
	# Briefly disable triggers in new room to prevent immediate re-trigger
	for child in new_room.get_children():
		if child.name.begins_with("ExitTrigger_"):
			child.set_deferred("monitoring", false)
	
	await get_tree().create_timer(0.5).timeout
	
	for child in new_room.get_children():
		if child.name.begins_with("ExitTrigger_"):
			child.set_deferred("monitoring", true)
	
	is_transitioning = false


# TRANSITION EDIT

func _get_or_create_overlay() -> ColorRect:
	# Reuse if already created
	var existing = get_tree().get_first_node_in_group("transition_overlay")
	if existing:
		return existing
	
	# Create a CanvasLayer so the overlay always renders on top of everything
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	get_tree().root.add_child(canvas)
	
	var rect = ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.add_to_group("transition_overlay")
	canvas.add_child(rect)
	return rect

func _set_room_active(room: Node2D, active: bool) -> void:
	# Show/hide visuals
	room.visible = active
	
	# Enable/disable all TileMapLayer collision
	for child in room.find_children("*", "TileMapLayer", true, false):
		child.collision_enabled = active
	
	# Enable/disable all enemies
	for child in room.find_children("*", "CharacterBody2D", true, false):
		child.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	
	# Enable/disable all Area2D except exit triggers (those are managed separately)
	for child in room.find_children("*", "Area2D", true, false):
		if child.name.begins_with("ExitTrigger_"):
			continue
		child.monitoring = active
		child.monitorable = active











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
