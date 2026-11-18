extends Node2D
class_name GuideNPC

@export var display_name: String = "ELDER"
@export var interaction_radius: float = 220.0

func _ready() -> void:
	z_index = 2
	var tag := Label.new()
	tag.name = "NameTag"
	tag.text = display_name
	tag.position = Vector2(-34.0, -78.0)
	tag.size = Vector2(90.0, 22.0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	add_child(tag)
	queue_redraw()

func _draw() -> void:
	# Original pixel-art elder with a blue travelling cloak and staff.
	draw_rect(Rect2(Vector2(-14.0, -42.0), Vector2(28.0, 27.0)), Color(0.76, 0.58, 0.42), true)
	draw_rect(Rect2(Vector2(-18.0, -18.0), Vector2(36.0, 30.0)), Color(0.18, 0.32, 0.58), true)
	draw_rect(Rect2(Vector2(-17.0, 8.0), Vector2(13.0, 18.0)), Color(0.24, 0.20, 0.17), true)
	draw_rect(Rect2(Vector2(4.0, 8.0), Vector2(13.0, 18.0)), Color(0.24, 0.20, 0.17), true)
	draw_circle(Vector2(-5.0, -31.0), 2.0, Color(0.12, 0.10, 0.08))
	draw_circle(Vector2(5.0, -31.0), 2.0, Color(0.12, 0.10, 0.08))
	draw_line(Vector2(-4.0, -21.0), Vector2(4.0, -21.0), Color(0.38, 0.16, 0.14), 2.0)
	draw_line(Vector2(23.0, -34.0), Vector2(23.0, 25.0), Color(0.42, 0.27, 0.15), 4.0)
	draw_circle(Vector2(23.0, -38.0), 6.0, Color(0.45, 0.82, 1.0))
	draw_rect(Rect2(Vector2(-17.0, -49.0), Vector2(34.0, 8.0)), Color(0.40, 0.28, 0.20), true)
