extends Node

const PROGRESS_PATH = "user://player_progress.json"
const RUN_PATH = "user://current_run.json"
var is_loading_run: bool = false

# ============================================================
# MAIN FUNCTIONS
# ============================================================

func save_game(is_death: bool):
	save_progression()

	if is_death:
		if FileAccess.file_exists(RUN_PATH):
			DirAccess.remove_absolute(RUN_PATH)

		# Read existing progress so we don't overwrite stats
		var progress = read_json(PROGRESS_PATH)
		if progress != null:
			progress["statistics"]["deaths"] += 1
			write_json(PROGRESS_PATH, progress)

		print("Saved on death (run deleted)")
	else:
		save_current_run()
		print("Saved current run")


func load_game():
	load_progression()

	if FileAccess.file_exists(RUN_PATH):
		is_loading_run = true
		load_current_run()
		is_loading_run = false
		print("Loaded run data")
	else:
		print("No run save found")


# ============================================================
# CURRENT RUN
# ============================================================

func save_current_run():
	var player = Autoload.main_char
	if player == null:
		print("ERROR: Player not found")
		return

	var data = {
		"current_health": player.cur_health,
		"player_position": {
			"x": player.global_position.x,
			"y": player.global_position.y
		},

		"melee_inventory": player.melee_weapons.map(func(w): return serialize_weapon(w)),
		"ranged_inventory": player.ranged_weapons.map(func(w): return serialize_weapon(w)),

		# Store index into inventory so we can restore the reference
		"equipped_melee_index": player.melee_weapons.find(player.melee_weapon),
		"equipped_ranged_index": player.ranged_weapons.find(player.ranged_weapon),

		"current_skills": player.augments.map(func(a): return serialize_augment(a)),

		"run_resources": player.resource_inv,

		"current_floor": 1,
		"bosses_defeated": [],

		"corpse_room_location": {
			"is_active": false,
			"location": null
		}
	}

	write_json(RUN_PATH, data)


func load_current_run():
	var data = read_json(RUN_PATH)
	if data == null:
		return

	var player = Autoload.main_char
	if player == null:
		print("ERROR: Player not found on load")
		return

	# Restore basic stats
	player.cur_health = data["current_health"]
	player.resource_inv = data["run_resources"]

	# Restore melee inventory
	player.melee_weapons.clear()
	for w_data in data["melee_inventory"]:
		player.melee_weapons.append(load_weapon_from_data(w_data))

	# Restore ranged inventory
	player.ranged_weapons.clear()
	for w_data in data["ranged_inventory"]:
		player.ranged_weapons.append(load_weapon_from_data(w_data))

	# Restore equipped weapons by index (keeps them as references into inventory)
	var melee_idx = data.get("equipped_melee_index", 0)
	var ranged_idx = data.get("equipped_ranged_index", 0)
	player.melee_weapon = player.melee_weapons[melee_idx] if melee_idx >= 0 else player.melee_weapons[0]
	player.ranged_weapon = player.ranged_weapons[ranged_idx] if ranged_idx >= 0 else player.ranged_weapons[0]
	player._equip_weapon(player.melee_weapon)

	# Restore augments and reapply stat effects
	player.augments.clear()
	for aug_data in data["current_skills"]:
		var aug = load_augment_from_data(aug_data)
		player.augments.append(aug)
		player._modify_augment_vals(aug, false)

	# Update health UI
	if player.has_node("TempHealthBar"):
		player.get_node("TempHealthBar").size = Vector2(player.cur_health / 10, player.get_node("TempHealthBar").size.y)
	if player.has_node("TempHealthNum"):
		player.get_node("TempHealthNum").text = str(player.cur_health)


# ============================================================
# PROGRESSION
# ============================================================

func save_progression():
	# Read existing data first so we don't wipe stats
	var existing = read_json(PROGRESS_PATH)

	var data = {
		"stored_weapons": [],
		"unlocked_recipes": [],
		"completed_objectives": [],
		"unlocked_floors": [],
		"statistics": {
			"deaths": 0,
			"runs": 0,
			"enemies_killed": 0
		}
	}

	# Merge existing stats in so they aren't reset on every save
	if existing != null:
		if existing.has("statistics"):
			data["statistics"] = existing["statistics"]
		if existing.has("stored_weapons"):
			data["stored_weapons"] = existing["stored_weapons"]
		if existing.has("unlocked_recipes"):
			data["unlocked_recipes"] = existing["unlocked_recipes"]
		if existing.has("completed_objectives"):
			data["completed_objectives"] = existing["completed_objectives"]
		if existing.has("unlocked_floors"):
			data["unlocked_floors"] = existing["unlocked_floors"]

	write_json(PROGRESS_PATH, data)


func load_progression():
	var data = read_json(PROGRESS_PATH)
	if data == null:
		print("No progression save yet")
		return

	print("Progression loaded:", data)


# ============================================================
# HELPERS
# ============================================================

func serialize_weapon(w: WeaponResource) -> Dictionary:
	return {
		"name": w.weapon_name,
		"script": w.weapon_script
	}

func serialize_augment(a: Augment) -> Dictionary:
	return {
		"name": a.aug_name,
		"type": a.type,
		"data": a.data,
		"price": a.price,
		"resource": a.resource
	}

func load_augment_from_data(data: Dictionary) -> Augment:
	var a = Augment.new()
	a.aug_name = data["name"]
	a.type = data["type"]
	a.data = data["data"]
	a.price = data["price"]
	a.resource = data["resource"]
	return a

func load_weapon_from_data(data: Dictionary) -> WeaponResource:
	var w = WeaponResource.new()
	w.weapon_name = data["name"]
	w.weapon_script = data["script"]
	return w

func write_json(path, data):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("ERROR: Could not open file for writing:", path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func read_json(path):
	if not FileAccess.file_exists(path):
		return null

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("ERROR: Could not open file for reading:", path)
		return null

	var text = file.get_as_text()
	file.close()

	return JSON.parse_string(text)
