extends RefCounted
class_name SaveManager
## 存档管理器：读写 JSON 存档文件，支持自定义存档路径

const CONFIG_PATH := "user://save_config.json"
const DEFAULT_SAVE_DIR := "user://saves"
const MAX_SLOTS := 5
const SAVE_VERSION := 1

static var _save_dir: String = ""  # 懒加载，首次调用时从配置读取


# ═══════════════════════════════════════════
# 路径管理
# ═══════════════════════════════════════════

## 获取当前存档目录（绝对路径或 user:// 格式）
static func get_save_dir() -> String:
	if _save_dir.is_empty():
		_save_dir = _load_config().get("save_dir", DEFAULT_SAVE_DIR)
	return _save_dir


## 设置存档目录
static func set_save_dir(path: String) -> void:
	_save_dir = path
	var cfg := _load_config()
	cfg["save_dir"] = path
	_save_config(cfg)


## 重置为默认路径
static func reset_save_dir() -> void:
	set_save_dir(DEFAULT_SAVE_DIR)


## 获取用于显示的路径（%APPDATA% → 实际路径）
static func get_display_path() -> String:
	var dir := get_save_dir()
	if dir.begins_with("user://"):
		return ProjectSettings.globalize_path(dir)
	return dir


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
	var dir := get_save_dir()
	DirAccess.make_dir_recursive_absolute(dir)

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
# 配置读写
# ═══════════════════════════════════════════

static func _load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	return json.get_data()


static func _save_config(cfg: Dictionary) -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(cfg, "\t"))
	file.close()


# ═══════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════

static func _slot_path(slot: int) -> String:
	return get_save_dir().path_join("slot_%d.json" % slot)
