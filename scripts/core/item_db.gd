extends RefCounted
class_name ItemDB
## 物品数据库：扫描 res://data/items/ 下所有 .tres，按 id 取用（带缓存）
## 新增物品只要往该目录丢 .tres 即可，无需注册

static var _cache: Dictionary = {}
static var _scanned: bool = false


static func get_item(id: String) -> Resource:
	if not _scanned:
		_scan()
	return _cache.get(id)


static func _scan() -> void:
	_scanned = true
	_scan_dir("res://data/items/")


static func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if dir.current_is_dir():
			_scan_dir(path + fname + "/")
		else:
			# 导出的包里文件会带 .remap 后缀，先去掉再判断/加载
			var clean := fname.trim_suffix(".remap")
			if clean.ends_with(".tres"):
				var res: Resource = load(path + clean)
				if res and res.get("id") != null and res.get("id") != "":
					_cache[res.get("id")] = res
		fname = dir.get_next()
