extends Node
class_name QuestTracker

signal updated(summary: String)
signal quest_completed(quest_id: String)

const QUESTS: Array[Dictionary] = [
	{"id": "gather_wood", "title": "WOODCUTTER", "description": "Collect 10 wood", "target": 10},
	{"id": "hunter", "title": "FIRST HUNT", "description": "Defeat 3 enemies", "target": 3},
	{"id": "dungeon_delver", "title": "DUNGEON DELVER", "description": "Open a dungeon chest", "target": 1}
]

var progress: Dictionary = {"gather_wood": 0, "hunter": 0, "dungeon_delver": 0}
var completed: Dictionary = {"gather_wood": false, "hunter": false, "dungeon_delver": false}

func sync_inventory(items: Dictionary) -> void:
	_set_progress("gather_wood", mini(int(items.get("wood", 0)), 10))

func record_enemy_defeat() -> void:
	_set_progress("hunter", mini(int(progress.get("hunter", 0)) + 1, 3))

func record_chest_opened() -> void:
	_set_progress("dungeon_delver", 1)

func _set_progress(quest_id: String, value: int) -> void:
	if bool(completed.get(quest_id, false)):
		return
	progress[quest_id] = maxi(value, 0)
	var target := _target_for(quest_id)
	if target > 0 and int(progress[quest_id]) >= target:
		completed[quest_id] = true
		quest_completed.emit(quest_id)
	updated.emit(get_summary())

func get_summary() -> String:
	var lines := PackedStringArray(["QUEST LOG"])
	for quest in QUESTS:
		var quest_id: String = quest["id"]
		var status := "DONE" if bool(completed.get(quest_id, false)) else "%d/%d" % [int(progress.get(quest_id, 0)), int(quest["target"])]
		lines.append("%s — %s (%s)" % [str(quest["title"]), str(quest["description"]), status])
	return "\n".join(lines)

func serialize() -> Dictionary:
	return {"progress": progress.duplicate(true), "completed": completed.duplicate(true)}

func restore(snapshot: Dictionary) -> bool:
	var raw_progress: Variant = snapshot.get("progress", {})
	var raw_completed: Variant = snapshot.get("completed", {})
	if not raw_progress is Dictionary or not raw_completed is Dictionary:
		return false
	for quest in QUESTS:
		var quest_id: String = quest["id"]
		var amount := int(raw_progress.get(quest_id, 0))
		if amount < 0 or amount > int(quest["target"]):
			return false
		progress[quest_id] = amount
		completed[quest_id] = bool(raw_completed.get(quest_id, false)) or amount >= int(quest["target"])
	updated.emit(get_summary())
	return true

func _target_for(quest_id: String) -> int:
	for quest in QUESTS:
		if str(quest["id"]) == quest_id:
			return int(quest["target"])
	return 0
