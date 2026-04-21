extends Node2D

## The root scene. Manages level transitions and holds the player.

@export var spawn_room_scene: PackedScene  # spawnRoom.tscn
@export var generator_scene: PackedScene   # generator_test.tscn (or a cleaned-up dungeon.tscn)

var player_scene: PackedScene = preload("res://Scenes/characterScenes/main_char.tscn")
var player: CharacterBody2D = null
var current_level: Node = null
var pause_menu_scene:PackedScene = preload("res://Scenes/UI/pause_menu.tscn")
var pause_menu: Control = null

func _ready() -> void:
	# Spawn the player once — it persists across all levels
	player = player_scene.instantiate()
	print("Player scene path: ", player_scene.resource_path)
	print("Player groups after instantiate: ", player.get_groups())
	player.max_dash_ticks = 50
	player.dash_speed = 1000
	# Give player enough resources for crafting tests
	player.resource_inv = [20,20,20,20,20]
	Autoload.main_char = player
	add_child(player)

	# Auto-equip sword for demo
	"""
	var sword_res = WeaponResource.new()
	sword_res.weapon_name = "Sword"
	sword_res.weapon_script = "res://Scripts/weaponScripts/weaponLogicScripts/sword.gd"
	player.melee_weapon = sword_res
	player.melee_weapons.append(sword_res)
	var weapon = player.get_node("Weapon")
	var weapon_script = load(sword_res.weapon_script)
	weapon.set_script(weapon_script)
	weapon.init()
	"""

	# Set up camera on the player
	var cam = player.find_child("Camera2D", true, false)
	if cam:
		cam.make_current()
		cam.zoom = Vector2(1, 1)

	var loading := save_manager.is_loading_run
	if loading:
		save_manager.load_game()
		
	# Load the spawn room first
	_load_spawn_room(loading)

	# Reset flag AFTER everything is done
	save_manager.is_loading_run = false

func _load_spawn_room(is_loading: bool) -> void:
	_clear_current_level()

	current_level = spawn_room_scene.instantiate()
	add_child(current_level)
	

	# Move player on top
	move_child(player, get_child_count() - 1)

	# Only set spawn position if NOT loading
	if not is_loading:
		var spawn_marker = current_level.find_child("spawnpoint", true, false)
		if spawn_marker:
			player.global_position = spawn_marker.global_position
		else:
			player.global_position = current_level.global_position

	# Connect dungeon entrance
	var entrance = current_level.find_child("DungeonEntrance", true, false)
	if entrance and entrance is Area2D:
		entrance.body_entered.connect(_on_dungeon_entrance_entered)


func _load_dungeon() -> void:
	print("DUNGEON LOADED")
	_clear_current_level()

	current_level = generator_scene.instantiate()
	add_child(current_level)
	move_child(player, get_child_count() - 1)
	
	var children = current_level.get_children()
	for i in children:
		print("CHILD TEST:", i.name)

	# The generator needs a reference to the player so it can position them
	# Wait one frame for the generator's _ready to finish placing rooms
	await get_tree().process_frame
	await get_tree().process_frame

	# Place player at the start room's origin
	if current_level.has_method("get_player_spawn_position"):
		player.global_position = current_level.get_player_spawn_position()
	else:
		player.global_position = Vector2.ZERO


func _clear_current_level() -> void:
	if current_level:
		current_level.queue_free()
		current_level = null


func _on_dungeon_entrance_entered(body: Node2D) -> void:
	if body == player:
		_load_dungeon()
