extends Control
class_name MobileControls

@export var joystick_radius: float = 76.0
@export var button_radius: float = 42.0
@export var edge_margin: float = 34.0

var _joystick_id: int = -1
var _joystick_origin := Vector2.ZERO
var _joystick_vector := Vector2.ZERO
var _held_actions: Dictionary = {}
var _jump_touch_id: int = -1
var _run_touch_id: int = -1
var _attack_touch_id: int = -1
var _mine_touch_id: int = -1
var _place_touch_id: int = -1
var _cycle_touch_id: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if not OS.has_feature("mobile"):
		return
	var left_center := Vector2(edge_margin + joystick_radius, size.y - edge_margin - joystick_radius)
	var jump_center := Vector2(size.x - edge_margin - button_radius, size.y - edge_margin - button_radius)
	var attack_center := Vector2(size.x - edge_margin - button_radius * 2.5, size.y - edge_margin - button_radius * 0.9)
	var run_center := Vector2(size.x - edge_margin - button_radius * 2.5, size.y - edge_margin - button_radius * 0.15)
	_draw_button(left_center, joystick_radius, "MOVE")
	var knob := left_center + _joystick_vector * joystick_radius * 0.55
	draw_circle(knob, joystick_radius * 0.34, Color(0.55, 0.8, 0.95, 0.62))
	_draw_button(jump_center, button_radius, "JUMP")
	_draw_button(attack_center, button_radius, "HIT")
	_draw_button(run_center, button_radius * 0.82, "RUN")
	_draw_button(_button_centers().mine, button_radius * 0.82, "MINE")
	_draw_button(_button_centers().place, button_radius * 0.82, "PLACE")
	_draw_button(_button_centers().cycle, button_radius * 0.82, "BLOCK")

func _draw_button(center: Vector2, radius: float, label: String) -> void:
	draw_circle(center, radius, Color(0.08, 0.13, 0.2, 0.52))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.75, 0.88, 1.0, 0.8), 3.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius * 0.48, 5.0), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 0.96, 14, Color.WHITE)

func _input(event: InputEvent) -> void:
	if not OS.has_feature("mobile"):
		return
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position)

func _handle_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		var centers := _button_centers()
		if pos.distance_to(centers.cycle) <= button_radius * 0.62:
			_cycle_touch_id = index
			_press_action("cycle_block")
		elif pos.distance_to(centers.mine) <= button_radius * 1.35:
			_mine_touch_id = index
			_press_action("mine")
		elif pos.distance_to(centers.place) <= button_radius * 1.35:
			_place_touch_id = index
			_press_action("place")
		elif pos.distance_to(centers.jump) <= button_radius * 1.5:
			_jump_touch_id = index
			_press_action("jump")
		elif pos.distance_to(centers.attack) <= button_radius * 1.5:
			_attack_touch_id = index
			_press_action("attack")
		elif pos.distance_to(centers.run) <= button_radius * 1.4:
			_run_touch_id = index
			_press_action("run")
		elif pos.x < size.x * 0.48 and _joystick_id == -1:
			_joystick_id = index
			_joystick_origin = pos
			_update_joystick(pos)
	else:
		if index == _cycle_touch_id:
			_cycle_touch_id = -1
			_release_action("cycle_block")
		elif index == _mine_touch_id:
			_mine_touch_id = -1
			_release_action("mine")
		elif index == _place_touch_id:
			_place_touch_id = -1
			_release_action("place")
		elif index == _jump_touch_id:
			_jump_touch_id = -1
			_release_action("jump")
		elif index == _attack_touch_id:
			_attack_touch_id = -1
			_release_action("attack")
		elif index == _run_touch_id:
			_run_touch_id = -1
			_release_action("run")
		elif index == _joystick_id:
			_joystick_id = -1
			_joystick_vector = Vector2.ZERO
			_release_action("move_left")
			_release_action("move_right")
			queue_redraw()

func _handle_drag(index: int, pos: Vector2) -> void:
	if index == _joystick_id:
		_update_joystick(pos)

func _update_joystick(pos: Vector2) -> void:
	var delta := pos - _joystick_origin
	_joystick_vector = delta.limit_length(joystick_radius) / joystick_radius
	_set_axis("move_left", _joystick_vector.x < -0.22)
	_set_axis("move_right", _joystick_vector.x > 0.22)
	queue_redraw()

func _set_axis(action: String, active: bool) -> void:
	if active:
		_press_action(action)
	else:
		_release_action(action)

func _press_action(action: String) -> void:
	if not _held_actions.get(action, false):
		_held_actions[action] = true
		Input.action_press(action)

func _release_action(action: String) -> void:
	if _held_actions.get(action, false):
		_held_actions[action] = false
		Input.action_release(action)

func _button_centers() -> Dictionary:
	return {
		"jump": Vector2(size.x - edge_margin - button_radius, size.y - edge_margin - button_radius),
		"attack": Vector2(size.x - edge_margin - button_radius * 2.5, size.y - edge_margin - button_radius * 1.35),
		"run": Vector2(size.x - edge_margin - button_radius * 2.5, size.y - edge_margin - button_radius * 0.15),
		"mine": Vector2(size.x - edge_margin - button_radius * 3.8, edge_margin + button_radius),
		"place": Vector2(size.x - edge_margin - button_radius, edge_margin + button_radius),
		"cycle": Vector2(size.x - edge_margin - button_radius * 2.4, edge_margin + button_radius)
	}

func _exit_tree() -> void:
	for action in _held_actions:
		Input.action_release(action)
