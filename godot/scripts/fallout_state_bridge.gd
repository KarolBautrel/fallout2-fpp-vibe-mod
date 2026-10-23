class_name FalloutStateBridge
extends Node

signal event_received(event: Dictionary)
signal status_changed(status: String)
signal bridge_error(message: String)

const SCHEMA := "fo2remix.bridge-v1"

@export var poll_interval := 0.10

var trace_path := ""
var status := "OFF"
var events_received := 0
var last_event: Dictionary = {}

var _absolute_path := ""
var _read_offset := 0
var _pending_text := ""
var _poll_time_remaining := 0.0
var _last_sequence := -1
var _configured := false


func configure(path: String, replay_existing: bool = false) -> void:
	trace_path = path
	_absolute_path = ProjectSettings.globalize_path(path)
	_read_offset = 0
	_pending_text = ""
	_last_sequence = -1
	events_received = 0
	last_event = {}
	_configured = true
	if FileAccess.file_exists(_absolute_path) and not replay_existing:
		var file := FileAccess.open(_absolute_path, FileAccess.READ)
		if file != null:
			_read_offset = file.get_length()
	_set_status("WAITING")


func _process(delta: float) -> void:
	if not _configured:
		return
	_poll_time_remaining -= delta
	if _poll_time_remaining > 0.0:
		return
	_poll_time_remaining = poll_interval
	poll_now()


func poll_now() -> void:
	if not _configured or not FileAccess.file_exists(_absolute_path):
		return

	var file := FileAccess.open(_absolute_path, FileAccess.READ)
	if file == null:
		_report_error("Cannot open bridge trace: %s" % _absolute_path)
		return

	var length := file.get_length()
	if length < _read_offset:
		_read_offset = 0
		_pending_text = ""
		_last_sequence = -1
		_set_status("RESET")
	if length == _read_offset:
		return

	file.seek(_read_offset)
	var new_bytes := file.get_buffer(length - _read_offset)
	_read_offset = file.get_position()
	_consume_text(new_bytes.get_string_from_utf8())


func _consume_text(text: String) -> void:
	var combined := _pending_text + text
	var lines := combined.split("\n", true)
	_pending_text = lines[lines.size() - 1]
	for index in range(lines.size() - 1):
		var line := lines[index].strip_edges()
		if not line.is_empty():
			_consume_line(line)


func _consume_line(line: String) -> void:
	var parsed: Variant = JSON.parse_string(line)
	if not parsed is Dictionary:
		_report_error("Invalid JSONL bridge record")
		return
	var event: Dictionary = parsed
	if String(event.get("schema", "")) != SCHEMA:
		_report_error("Unsupported bridge schema: %s" % event.get("schema", ""))
		return
	if not event.has("sequence") or not event.has("event"):
		_report_error("Bridge record is missing sequence or event")
		return

	var sequence := int(event["sequence"])
	var event_name := String(event["event"])
	if event_name == "session_started":
		if sequence != 0:
			_report_error("Bridge session must start at sequence 0")
			return
		_last_sequence = 0
		_set_status("CONNECTED")
	elif _last_sequence == -1:
		_report_error("Bridge event received before session_started")
		return
	elif sequence != _last_sequence + 1:
		_report_error(
			"Bridge sequence gap: expected %d, received %d" % [_last_sequence + 1, sequence]
		)
		return
	else:
		_last_sequence = sequence
		_set_status("CONNECTED")

	events_received += 1
	last_event = event.duplicate(true)
	event_received.emit(last_event)


func _set_status(value: String) -> void:
	if status == value:
		return
	status = value
	status_changed.emit(status)


func _report_error(message: String) -> void:
	_set_status("ERROR")
	bridge_error.emit(message)
	push_error(message)
