extends Node

var day_night: Node
var label: Label


func _process(_delta: float) -> void:
	if not day_night or not label:
		return
	var hours: float = day_night.get_time_hours()
	var h: int = int(hours) % 24
	var m: int = int((hours - int(hours)) * 60)
	label.text = "%02d:%02d" % [h, m]
