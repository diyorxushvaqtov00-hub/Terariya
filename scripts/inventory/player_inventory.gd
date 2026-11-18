extends Node
class_name PlayerInventory

signal changed(items: Dictionary)

var items: Dictionary = {}
var tool_durability: Dictionary = {}
var equipped_armor: String = ""
var weapon_upgrade_levels: Dictionary = {}
var armor_upgrade_levels: Dictionary = {}

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
	},
	"wooden_bucket": {
		"ingredients": {"wooden_planks": 5},
		"output": "empty_bucket",
		"amount": 1
	},
	"torch": {
		"ingredients": {"wood": 1},
		"output": "torch",
		"amount": 4
	},
	"wooden_armor": {
		"ingredients": {"wooden_planks": 12},
		"output": "wooden_armor",
		"amount": 1
	},
	"copper_sword": {
		"ingredients": {"ore": 10, "wooden_planks": 2},
		"output": "copper_sword",
		"amount": 1
	},
	"eye_summon": {
		"ingredients": {"ore": 8, "stone": 12, "wood": 5},
		"output": "eye_summon",
		"amount": 1
	},
	"silver_sword": {"ingredients": {"silver_ore": 12, "wooden_planks": 4}, "output": "silver_sword", "amount": 1},
	"gold_sword": {"ingredients": {"gold_ore": 10, "wooden_planks": 5}, "output": "gold_sword", "amount": 1},
	"silver_armor": {"ingredients": {"silver_ore": 28, "wooden_planks": 8}, "output": "silver_armor", "amount": 1},
	"gold_armor": {"ingredients": {"gold_ore": 24, "wooden_planks": 10}, "output": "gold_armor", "amount": 1},
	"anvil": {"ingredients": {"stone": 20, "ore": 10, "wooden_planks": 8}, "output": "anvil", "amount": 1},
	"spider_summon": {"ingredients": {"spider_fang": 6, "silver_ore": 20, "gold_ore": 8}, "output": "spider_summon", "amount": 1},
	"magma_heart": {"ingredients": {"magma_core": 8, "gold_ore": 30, "magma_rock": 20}, "output": "magma_heart", "amount": 1},
	"obsidian_sword": {"ingredients": {"magma_core": 12, "gold_ore": 18, "wooden_planks": 8}, "output": "obsidian_sword", "amount": 1},
	"obsidian_armor": {"ingredients": {"magma_core": 24, "gold_ore": 24, "wooden_planks": 12}, "output": "obsidian_armor", "amount": 1},
	"guardian_totem": {"ingredients": {"glow_mushroom": 12, "mushroom_soil": 18, "silver_ore": 15}, "output": "guardian_totem", "amount": 1},
	"dungeon_key": {"ingredients": {"silver_ore": 6, "gold_ore": 3, "spider_fang": 2}, "output": "dungeon_key", "amount": 3},
	"mushroom_blade": {"ingredients": {"glow_mushroom": 18, "magma_core": 4, "wooden_planks": 10}, "output": "mushroom_blade", "amount": 1},
	"fungal_armor": {"ingredients": {"glow_mushroom": 24, "mushroom_soil": 20, "silver_ore": 18}, "output": "fungal_armor", "amount": 1}
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

func buy_item(item_id: String, amount: int, price_per_item: int) -> bool:
	if item_id.is_empty() or amount <= 0 or price_per_item <= 0:
		return false
	var total_price := amount * price_per_item
	if total_price > 999999 or count("coins") < total_price:
		return false
	if not remove_item("coins", total_price):
		return false
	add_item(item_id, amount)
	return true

func sell_item(item_id: String, amount: int, price_per_item: int) -> bool:
	if item_id.is_empty() or item_id == "coins" or amount <= 0 or price_per_item <= 0:
		return false
	if count(item_id) < amount:
		return false
	var total_price := amount * price_per_item
	if total_price > 999999:
		return false
	if not remove_item(item_id, amount):
		return false
	add_item("coins", total_price)
	return true

func can_craft(recipe_id: String) -> bool:
	if recipe_id in ["wooden_pickaxe", "wooden_axe"] and count(recipe_id) > 0:
		return false
	if recipe_id in ["silver_sword", "gold_sword", "silver_armor", "gold_armor", "obsidian_sword", "obsidian_armor", "mushroom_blade", "fungal_armor"] and count("anvil") <= 0:
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

func equip_armor(armor_id: String) -> bool:
	if armor_id.is_empty():
		equipped_armor = ""
		changed.emit(items.duplicate())
		return true
	if count(armor_id) <= 0 or armor_id not in ["wooden_armor", "silver_armor", "gold_armor", "obsidian_armor", "fungal_armor"]:
		return false
	equipped_armor = armor_id
	changed.emit(items.duplicate())
	return true

func get_armor_defense() -> int:
	match equipped_armor:
		"wooden_armor":
			return 6 + get_armor_upgrade_level("wooden_armor")
		"silver_armor":
			return 12 + get_armor_upgrade_level("silver_armor")
		"gold_armor":
			return 20 + get_armor_upgrade_level("gold_armor")
		"obsidian_armor":
			return 28 + get_armor_upgrade_level("obsidian_armor")
		"fungal_armor":
			return 22 + get_armor_upgrade_level("fungal_armor")
		_:
			return 0

func get_best_weapon_id() -> String:
	for weapon_id in ["obsidian_sword", "queens_fang", "mushroom_blade", "gold_sword", "silver_sword", "copper_sword", "stone_sword"]:
		if count(weapon_id) > 0:
			return weapon_id
	return ""

func get_weapon_upgrade_level(weapon_id: String) -> int:
	return int(weapon_upgrade_levels.get(weapon_id, 0))

func get_armor_upgrade_level(armor_id: String) -> int:
	return int(armor_upgrade_levels.get(armor_id, 0))

func upgrade_best_weapon() -> bool:
	var weapon_id := get_best_weapon_id()
	if weapon_id.is_empty() or count("anvil") <= 0:
		return false
	var level := get_weapon_upgrade_level(weapon_id)
	if level >= 10:
		return false
	var material := "stone"
	var amount := 4 + level * 2
	match weapon_id:
		"copper_sword":
			material = "ore"
			amount = 2 + level
		"silver_sword":
			material = "silver_ore"
			amount = 2 + level
		"gold_sword":
			material = "gold_ore"
			amount = 2 + level
		"queens_fang":
			material = "spider_fang"
			amount = 2 + level
		"obsidian_sword":
			material = "magma_core"
			amount = 2 + level
		"mushroom_blade":
			material = "glow_mushroom"
			amount = 3 + level
	if not remove_item(material, amount):
		return false
	weapon_upgrade_levels[weapon_id] = level + 1
	changed.emit(items.duplicate())
	return true

func upgrade_equipped_armor() -> bool:
	if equipped_armor.is_empty() or count("anvil") <= 0:
		return false
	var level := get_armor_upgrade_level(equipped_armor)
	if level >= 10:
		return false
	var material := "wooden_planks"
	var amount := 4 + level * 2
	match equipped_armor:
		"silver_armor":
			material = "silver_ore"
			amount = 3 + level
		"gold_armor":
			material = "gold_ore"
			amount = 3 + level
		"obsidian_armor":
			material = "magma_core"
			amount = 3 + level
		"fungal_armor":
			material = "glow_mushroom"
			amount = 4 + level
	if not remove_item(material, amount):
		return false
	armor_upgrade_levels[equipped_armor] = level + 1
	changed.emit(items.duplicate())
	return true

func serialize() -> Dictionary:
	var snapshot: Dictionary = {}
	for item_id in items:
		snapshot[str(item_id)] = maxi(int(items[item_id]), 0)
	return {"items": snapshot, "tool_durability": tool_durability.duplicate(true), "equipped_armor": equipped_armor, "weapon_upgrade_levels": weapon_upgrade_levels.duplicate(true), "armor_upgrade_levels": armor_upgrade_levels.duplicate(true)}

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
	var restored_armor := str(snapshot.get("equipped_armor", ""))
	if not restored_armor.is_empty() and restored.get(restored_armor, 0) <= 0:
		restored_armor = ""
	if not restored_armor.is_empty() and restored_armor not in ["wooden_armor", "silver_armor", "gold_armor", "obsidian_armor", "fungal_armor"]:
		return false
	var restored_weapon_upgrades: Dictionary = _validated_upgrade_levels(snapshot.get("weapon_upgrade_levels", {}), ["stone_sword", "copper_sword", "silver_sword", "gold_sword", "queens_fang", "obsidian_sword", "mushroom_blade"])
	var restored_armor_upgrades: Dictionary = _validated_upgrade_levels(snapshot.get("armor_upgrade_levels", {}), ["wooden_armor", "silver_armor", "gold_armor", "obsidian_armor", "fungal_armor"])
	items = restored
	tool_durability = restored_durability
	equipped_armor = restored_armor
	weapon_upgrade_levels = restored_weapon_upgrades
	armor_upgrade_levels = restored_armor_upgrades
	changed.emit(items.duplicate())
	return true

func _validated_upgrade_levels(raw: Variant, allowed_ids: Array) -> Dictionary:
	var result: Dictionary = {}
	if not raw is Dictionary:
		return result
	for item_id in raw:
		var level_value: Variant = raw[item_id]
		if str(item_id) not in allowed_ids or not level_value is int:
			continue
		var level := clampi(int(level_value), 0, 10)
		if level > 0:
			result[str(item_id)] = level
	return result
