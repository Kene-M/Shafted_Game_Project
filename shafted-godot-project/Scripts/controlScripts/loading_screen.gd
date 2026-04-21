extends Control

@onready var panel: PanelContainer = $CanvasLayer/PanelContainer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false

func show_loading():
	panel.visible = true

func hide_loading():
	panel.visible = false
