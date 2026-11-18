extends Node2D
class_name MerchantNPC

@export var display_name: String = "TRADER"
@export var interaction_radius: float = 260.0

func _ready() -> void:
	z_index = 2
	var name_tag := Label.new()
	name_tag.name = "NameTag"
	name_tag.text = display_name
	name_tag.position = Vector2(-34.0, -82.0)
	name_tag.size = Vector2(90.0, 22.0)
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.add_theme_font_size_override("font_size", 14)
	name_tag.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	add_child(name_tag)
	queue_redraw()

func _draw() -> void:
	# A compact, original pixel-art-style merchant readable at mobile scale.
	draw_rect(Rect2(Vector2(-15.0, -42.0), Vector2(30.0, 28.0)), Color(0.78, 0.58, 0.38), true)
	draw_rect(Rect2(Vector2(-18.0, -17.0), Vector2(36.0, 29.0)), Color(0.20, 0.42, 0.34), true)
	draw_rect(Rect2(Vector2(-18.0, 7.0), Vector2(36.0, 9.0)), Color(0.34, 0.22, 0.14), true)
	draw_rect(Rect2(Vector2(-13.0, 16.0), Vector2(10.0, 13.0)), Color(0.28, 0.20, 0.16), true)
	draw_rect(Rect2(Vector2(3.0, 16.0), Vector2(10.0, 13.0)), Color(0.28, 0.20, 0.16), true)
	draw_circle(Vector2(-5.0, -30.0), 2.0, Color(0.12, 0.10, 0.08))
	draw_circle(Vector2(6.0, -30.0), 2.0, Color(0.12, 0.10, 0.08))
	draw_line(Vector2(-4.0, -22.0), Vector2(5.0, -22.0), Color(0.30, 0.12, 0.10), 2.0)
	draw_rect(Rect2(Vector2(-23.0, -49.0), Vector2(46.0, 9.0)), Color(0.56, 0.30, 0.12), true)
	draw_rect(Rect2(Vector2(-17.0, -57.0), Vector2(34.0, 9.0)), Color(0.72, 0.42, 0.18), true)
	draw_rect(Rect2(Vector2(-5.0, -58.0), Vector2(10.0, 3.0)), Color(0.92, 0.76, 0.35), true)
	draw_circle(Vector2(22.0, -14.0), 8.0, Color(0.95, 0.74, 0.20))
	draw_circle(Vector2(22.0, -14.0), 4.0, Color(0.65, 0.42, 0.10))
