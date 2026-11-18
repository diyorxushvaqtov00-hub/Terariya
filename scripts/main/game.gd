extends Node2D

@onready var health_label: Label = $HUD/HealthLabel

func _ready() -> void:
	var player := $Player
	player.health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(player.health, player.max_health)

func _on_player_health_changed(current: int, maximum: int) -> void:
	health_label.text = "HP  %d / %d" % [current, maximum]
