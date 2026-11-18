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

func serialize() -> Dictionary:
	var snapshot: Dictionary = {}
	for item_id in items:
		snapshot[str(item_id)] = maxi(int(items[item_id]), 0)
	return snapshot

func restore(snapshot: Dictionary) -> bool:
	var restored: Dictionary = {}
	for item_id in snapshot:
		var amount_value: Variant = snapshot[item_id]
		if not amount_value is int and not amount_value is float:
			return false
		var amount := int(amount_value)
		if amount < 0 or amount > 999999:
			return false
		if not str(item_id).is_empty():
			restored[str(item_id)] = amount
	items = restored
	changed.emit(items.duplicate())
	return true
