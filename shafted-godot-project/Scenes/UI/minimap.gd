extends Control

# ── Minimap controller ────────────────────────────────────────────────────
# Approach: real ColorRect nodes as room markers, positioned inside a
# clipped container. Player dot is a ColorRect that moves within the
# mini panel. Full map spawns one ColorRect per room on open.

var _full_open: bool = false

# Mini panel nodes
@onready var mini_panel    : Panel     = $MinimapPanel
@onready var mini_grid     : Control   = $MinimapPanel/MiniGrid
@onready var player_dot    : ColorRect = $MinimapPanel/MiniGrid/PlayerDot

# Full map nodes (siblings of MinimapRoot on the CanvasLayer)
@onready var full_overlay  : Control   = $"../FullMapOverlay"
@onready var full_grid     : Control   = $"../FullMapOverlay/FullGrid"

# Room marker ColorRects spawned at dungeon load
var _mini_room_markers  : Dictionary = {}   # Vector2i -> ColorRect  (mini)
var _full_room_markers  : Dictionary = {}   # Vector2i -> ColorRect  (full)

# Mini panel display constants
const MINI_CELL   := Vector2(18.0, 18.0)   # size of each room box in mini view
const MINI_GAP    := 4.0                    # gap between room boxes
const MINI_STEP   := Vector2(22.0, 22.0)   # MINI_CELL + MINI_GAP

# Full map display constants
const FULL_CELL   := Vector2(36.0, 36.0)
const FULL_GAP    := 8.0
const FULL_STEP   := Vector2(44.0, 44.0)

# Corridor connector size (thin rect bridging two rooms)
const CORR_W      := 6.0


func _ready() -> void:
	add_to_group("minimap")
	full_overlay.visible = false
	# Wait a frame so the CanvasLayer has sized everything
	await get_tree().process_frame
	_build_markers()


func _process(_delta: float) -> void:
	if Autoload.dungeon_generator == null:
		return
	_update_mini()
	if Input.is_action_just_pressed("toggle_map"):
		_toggle_full_map()


# ── Build all room markers once after dungeon is ready ────────────────────

func _build_markers() -> void:
	var gen = Autoload.dungeon_generator
	if gen == null:
		return

	# Clear any old markers
	for child in mini_grid.get_children():
		if child.name != "PlayerDot":
			child.queue_free()
	for child in full_grid.get_children():
		child.queue_free()
	_mini_room_markers.clear()
	_full_room_markers.clear()

	for grid_pos: Vector2i in gen.grid.keys():
		var room_type : String = gen.grid[grid_pos]
		var col       : Color  = _room_color(room_type)

		# ── Mini marker ──
		var mr := ColorRect.new()
		mr.color         = col
		mr.custom_minimum_size = MINI_CELL
		mr.size          = MINI_CELL
		mr.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		mini_grid.add_child(mr)
		_mini_room_markers[grid_pos] = mr

		# ── Full marker ──
		var fr := ColorRect.new()
		fr.color         = col
		fr.custom_minimum_size = FULL_CELL
		fr.size          = FULL_CELL
		fr.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		full_grid.add_child(fr)
		_full_room_markers[grid_pos] = fr

	# Spawn corridor connectors for the full map
	_build_full_corridors(gen)

	# Initial position pass
	_layout_mini_markers(gen)
	_layout_full_markers(gen)
	_update_mini()


func _build_full_corridors(gen) -> void:
	var dirs := {
		"North": Vector2i(0, -1),
		"South": Vector2i(0,  1),
		"East" : Vector2i(1,  0),
		"West" : Vector2i(-1, 0),
	}
	var done : Dictionary = {}
	for grid_pos: Vector2i in gen.grid.keys():
		for dir_name in dirs:
			var neighbor : Vector2i = grid_pos + dirs[dir_name]
			if not gen.grid.has(neighbor):
				continue
			# Draw each corridor once
			var key := Vector2i(min(grid_pos.x, neighbor.x), min(grid_pos.y, neighbor.y))
			var key2 : String = str(key) + dir_name
			if done.has(key2):
				continue
			done[key2] = true

			var corr := ColorRect.new()
			corr.color        = Color(0.40, 0.40, 0.40, 1.0)
			corr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Size set during layout
			corr.set_meta("from", grid_pos)
			corr.set_meta("to",   neighbor)
			corr.set_meta("dir",  dir_name)
			full_grid.add_child(corr)


func _layout_mini_markers(gen) -> void:
	# Find grid bounds
	var min_x := 0; var max_x := 0; var min_y := 0; var max_y := 0
	for p: Vector2i in gen.grid.keys():
		if p.x < min_x: min_x = p.x
		if p.x > max_x: max_x = p.x
		if p.y < min_y: min_y = p.y
		if p.y > max_y: max_y = p.y

	var grid_w := float(max_x - min_x + 1) * MINI_STEP.x
	var grid_h := float(max_y - min_y + 1) * MINI_STEP.y
	var origin := (mini_grid.size - Vector2(grid_w, grid_h)) / 2.0

	for grid_pos: Vector2i in _mini_room_markers.keys():
		var mr : ColorRect = _mini_room_markers[grid_pos]
		mr.position = origin + Vector2(grid_pos.x - min_x, grid_pos.y - min_y) * MINI_STEP


func _layout_full_markers(gen) -> void:
	var min_x := 0; var max_x := 0; var min_y := 0; var max_y := 0
	for p: Vector2i in gen.grid.keys():
		if p.x < min_x: min_x = p.x
		if p.x > max_x: max_x = p.x
		if p.y < min_y: min_y = p.y
		if p.y > max_y: max_y = p.y

	var grid_w := float(max_x - min_x + 1) * FULL_STEP.x
	var grid_h := float(max_y - min_y + 1) * FULL_STEP.y
	var origin := (full_grid.size - Vector2(grid_w, grid_h)) / 2.0

	for grid_pos: Vector2i in _full_room_markers.keys():
		var fr : ColorRect = _full_room_markers[grid_pos]
		fr.position = origin + Vector2(grid_pos.x - min_x, grid_pos.y - min_y) * FULL_STEP

	# Position corridor rects
	for child in full_grid.get_children():
		if not child.has_meta("from"):
			continue
		var gfrom : Vector2i = child.get_meta("from")
		var gto   : Vector2i = child.get_meta("to")
		var dir   : String   = child.get_meta("dir")
		var pf    : Vector2  = origin + Vector2(gfrom.x - min_x, gfrom.y - min_y) * FULL_STEP + FULL_CELL / 2.0
		var pt    : Vector2  = origin + Vector2(gto.x   - min_x, gto.y   - min_y) * FULL_STEP + FULL_CELL / 2.0
		match dir:
			"East", "West":
				child.size     = Vector2(abs(pt.x - pf.x) - FULL_CELL.x, CORR_W)
				child.position = Vector2(min(pf.x, pt.x) + FULL_CELL.x / 2.0, pf.y - CORR_W / 2.0)
			"North", "South":
				child.size     = Vector2(CORR_W, abs(pt.y - pf.y) - FULL_CELL.y)
				child.position = Vector2(pf.x - CORR_W / 2.0, min(pf.y, pt.y) + FULL_CELL.y / 2.0)


# ── Mini view: highlight current room, dim others, move player dot ────────

func _update_mini() -> void:
	var gen = Autoload.dungeon_generator
	if gen == null:
		return

	var cur : Vector2i = gen.current_room_pos

	for grid_pos: Vector2i in _mini_room_markers.keys():
		var mr : ColorRect = _mini_room_markers[grid_pos]
		if grid_pos == cur:
			mr.color = _room_color(gen.grid.get(grid_pos, "normal"))
			mr.size  = MINI_CELL
		else:
			mr.color = _room_color(gen.grid.get(grid_pos, "normal")).darkened(0.55)
			mr.size  = MINI_CELL

	# Move player dot inside the current room marker
	var cur_marker : ColorRect = _mini_room_markers.get(cur)
	if cur_marker:
		var player = Autoload.main_char
		var room   = gen.placed_rooms.get(cur)
		if player and room:
			# Rough fraction of player position within room (use a fixed room size estimate)
			var room_world_size := Vector2(1280.0, 720.0)
			var frac : Vector2 = ((player.global_position - room.global_position) / room_world_size).clamp(Vector2.ZERO, Vector2.ONE)
			player_dot.position = cur_marker.position + frac * MINI_CELL - player_dot.size / 2.0
			player_dot.visible  = true
		else:
			player_dot.visible = false

	# Highlight current room outline — done via modulate trick
	if cur_marker:
		cur_marker.modulate = Color(1.3, 1.3, 1.3, 1.0)
	for grid_pos: Vector2i in _mini_room_markers.keys():
		if grid_pos != cur:
			_mini_room_markers[grid_pos].modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Update full map current room highlight
	for grid_pos: Vector2i in _full_room_markers.keys():
		var fr : ColorRect = _full_room_markers[grid_pos]
		if grid_pos == cur:
			fr.modulate = Color(1.4, 1.4, 1.4, 1.0)
		else:
			fr.modulate = Color(1.0, 1.0, 1.0, 1.0)


# ── Full map toggle ────────────────────────────────────────────────────────

func _toggle_full_map() -> void:
	_full_open = not _full_open
	full_overlay.visible = _full_open
	if _full_open:
		# Re-layout in case viewport size changed
		await get_tree().process_frame
		_layout_full_markers(Autoload.dungeon_generator)


func _on_click_zone_pressed() -> void:
	_toggle_full_map()


# Called by game_manager after dungeon_ready signal
func on_dungeon_loaded() -> void:
	await get_tree().process_frame
	_build_markers()


# ── Helpers ────────────────────────────────────────────────────────────────

func _room_color(room_type: String) -> Color:
	match room_type:
		"start":    return Color(0.25, 0.55, 1.00)
		"boss":     return Color(0.80, 0.18, 0.18)
		"treasure": return Color(0.90, 0.72, 0.10)
		_:          return Color(0.32, 0.32, 0.32)
