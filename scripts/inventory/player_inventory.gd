extends Node
class_name PlayerInventory

signal changed(items: Dictionary)

var items: Dictionary = {}

func _ready() -> void:
	add_item("dirt", 20)

func count(item_id: String) -> int:
	return int(items.get(item_id, 0))

func add_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	items[item_id] = count(item_id) + amount
	changed.emit(items.duplicate())

func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or count(item_id) < amount:
		return false
	items[item_id] = count(item_id) - amount
	changed.emit(items.duplicate())
	return true
