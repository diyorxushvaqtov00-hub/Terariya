extends Node
class_name PlayerInventory

signal changed(items: Dictionary)

var items: Dictionary = {}
var tool_durability: Dictionary = {}

const RECIPES: Dictionary = {
	"wooden_planks": {
		"ingredients": {"wood": 2},
		"output": "wooden_planks",
		"amount": 4
	},
	"workbench": {
		"ingredients": {"wood": 10},
		"output": "workbench",
		"amount": 1
	},
	"stone_sword": {
		"ingredients": {"wood": 3, "stone": 8},
		"output": "stone_sword",
		"amount": 1
	},
	"wooden_pickaxe": {
		"ingredients": {"wooden_planks": 5, "stone": 3},
		"output": "wooden_pickaxe",
		"amount": 1
	},
	"wooden_axe": {
		"ingredients": {"wooden_planks": 4, "stone": 2},
		"output": "wooden_axe",
		"amount": 1
	}
}

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

func can_craft(recipe_id: String) -> bool:
	if recipe_id in ["wooden_pickaxe", "wooden_axe"] and count(recipe_id) > 0:
		return false
	var recipe: Variant = RECIPES.get(recipe_id, null)
	if not recipe is Dictionary:
		return false
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for item_id in ingredients:
		if count(str(item_id)) < int(ingredients[item_id]):
			return false
	return true

func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id):
		return false
	var recipe: Dictionary = RECIPES[recipe_id]
	var ingredients: Dictionary = recipe["ingredients"]
	for item_id in ingredients:
		remove_item(str(item_id), int(ingredients[item_id]))
	var output_id := str(recipe["output"])
	add_item(output_id, int(recipe.get("amount", 1)))
	if output_id in ["wooden_pickaxe", "wooden_axe"]:
		tool_durability[output_id] = 40 if output_id == "wooden_pickaxe" else 35
		changed.emit(items.duplicate())
	return true

func use_tool(tool_id: String) -> bool:
	if count(tool_id) <= 0 or not tool_durability.has(tool_id):
		return false
	tool_durability[tool_id] = int(tool_durability[tool_id]) - 1
	if int(tool_durability[tool_id]) <= 0:
		tool_durability.erase(tool_id)
		remove_item(tool_id, 1)
	else:
		changed.emit(items.duplicate())
	return true

func get_tool_durability(tool_id: String) -> int:
	return int(tool_durability.get(tool_id, 0))

func serialize() -> Dictionary:
	var snapshot: Dictionary = {}
	for item_id in items:
		snapshot[str(item_id)] = maxi(int(items[item_id]), 0)
	return {"items": snapshot, "tool_durability": tool_durability.duplicate(true)}

func restore(snapshot: Dictionary) -> bool:
	var source: Variant = snapshot.get("items", snapshot)
	if not source is Dictionary:
		return false
	var restored: Dictionary = {}
	for item_id in source:
		var amount_value: Variant = source[item_id]
		if not amount_value is int and not amount_value is float:
			return false
		var amount := int(amount_value)
		if amount < 0 or amount > 999999:
			return false
		if not str(item_id).is_empty():
			restored[str(item_id)] = amount
	var restored_durability: Dictionary = {}
	var durability_source: Variant = snapshot.get("tool_durability", {})
	if not durability_source is Dictionary:
		return false
	for tool_id in durability_source:
		var durability_value: Variant = durability_source[tool_id]
		if not durability_value is int or int(durability_value) < 0 or int(durability_value) > 10000:
			return false
		if restored.get(str(tool_id), 0) > 0 and int(durability_value) > 0:
			restored_durability[str(tool_id)] = int(durability_value)
	items = restored
	tool_durability = restored_durability
	changed.emit(items.duplicate())
	return true
