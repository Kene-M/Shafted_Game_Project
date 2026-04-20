extends Node

func init():
	var char = get_parent()
	char.cur_run = "run"
	if $"../AnimatedSprite2D".animation == "no_arms_run":
		$"../AnimatedSprite2D".play(char.cur_run)
	$Sprite2D2.texture = null
