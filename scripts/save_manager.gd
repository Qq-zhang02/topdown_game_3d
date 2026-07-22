extends RefCounted
class_name SaveManager
## 存档管理器：读写 user://saves/ 下的 JSON 存档文件

const SAVE_DIR := "user://saves"
const MAX_SLOTS := 5
const SAVE_VERSION := 1


# ═══════════════════════════════════════════
# 存档信息（轻量，不加载完整数据）
# ═══════════════════════════════════════════

static func get_save_info(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"slot": slot, "empty": true}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"slot": slot, "empty": true}

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		return {"slot": slot, "empty": true, "error": true}

	var data: Dictionary = json.get_data()
	return {
		"slot": slot,
		"empty": false,
		"save_name": data.get("save_name", "存档 %d" % (slot + 1)),
		"character_model": data.get("character_model", ""),
		"character_skin": data.get("character_skin", ""),
		"timestamp": data.get("timestamp", ""),
		"play_time": data.get("play_time", 0.0),
		"player_health": data.get("player", {}).get("health", 100.0),
	}


static func list_saves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(MAX_SLOTS):
		result.append(get_save_info(i))
	return result


# ═══════════════════════════════════════════
# 完整存档读写
# ═══════════════════════════════════════════

static func load_save(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		return {}

	return json.get_data()


static func save_game(slot: int, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] 无法写入: " + path)
		return false

	var json := JSON.stringify(data, "\t")
	file.store_string(json)
	file.close()
	return true


static func delete_save(slot: int) -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK


static func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


# ═══════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════

static func _slot_path(slot: int) -> String:
	return SAVE_DIR.path_join("slot_%d.json" % slot)
