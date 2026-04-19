extends Node

const PROGRESS_PATH = "user://player_progress.json"
const RUN_PATH = "user://current_run.json"

# ============================================================
# MAIN FUNCTIONS
# ============================================================

func save_game(is_death: bool):
	save_progression()

	if is_death:
		if FileAccess.file_exists(RUN_PATH):
			DirAccess.remove_absolute(RUN_PATH)

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
		load_current_run()
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

		"equipped_weapons": [
			player.melee_weapon.weapon_name,
			player.ranged_weapon.weapon_name
		],

		"current_skills": player.augments.map(func(a): return a.name),

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
	
	#load player position
	if data.has("player_position"):
		var pos = data["player_position"]
		player.global_position = Vector2(pos["x"], pos["y"])
	
	# Restore weapons
	var weapons = data["equipped_weapons"]
	player.melee_weapon = load_weapon_by_name(weapons[0])
	player.ranged_weapon = load_weapon_by_name(weapons[1])

	# Restore augments
	player.augments.clear()
	for aug_name in data["current_skills"]:
		player.augments.append(load_augment_by_name(aug_name))

	if player.has_node("TempHealthBar"):
		var bar = player.get_node("TempHealthBar")
		bar.size = Vector2((player.cur_health / 10), bar.size.y)

	if player.has_node("TempHealthNum"):
		player.get_node("TempHealthNum").text = str(player.cur_health)


# ============================================================
# PROGRESSION
# ============================================================

func save_progression():
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


# ============================================================
# TEMP LOOKUP SYSTEM
# ============================================================

func load_weapon_by_name(name: String):
	var w = WeaponResource.new()
	w.weapon_name = name
	return w


func load_augment_by_name(name: String):
	var a = Augment.new()
	a.name = name
	return a
