class_name Enemy
extends CharacterBody2D


@export var speed = 50
@export var nav_agent: NavigationAgent2D

var target_node = null
var home_pos = Vector2.ZERO

func _ready():
	home_pos = self.global_position
	
	nav_agent.path_desired_distance = 4
	nav_agent.target_desired_distance = 4

func _physics_process(_delta):
	if nav_agent.is_navigation_finished():
		return
	
	var axis = to_local(nav_agent.get_next_path_position()).normalized()
	velocity = axis * speed
	
	move_and_slide()

func recalc_path():
	if target_node:
		nav_agent.target_position = target_node.global_position
	else:
		nav_agent.target_position = home_pos

func _on_recalculate_timer_timeout():
	recalc_path()

func _on_aggro_range_area_entered(area):
	target_node = area.owner
	


func _on_de_aggro_range_area_exited(area: Area2D) -> void:
	if area.owner == target_node:
		target_node = null
