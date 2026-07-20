## In-memory stand-in for [FileBackend], for tests.
##
## Exists so no test ever reads or writes the real `user://` save. A suite that touches a
## player's save file is a suite that can destroy one — and one that READS it makes every
## test order-dependent on whatever the last run happened to leave behind.
##
## preload()-ed rather than class_name'd: a class_name under tests/ would enter the
## production global registry (ADR-0002 §5).
extends RefCounted

var files: Dictionary = {}


class MemoryFile extends RefCounted:
	var _backend
	var _path: String
	var _buffer: String = ""

	func _init(backend, path: String) -> void:
		_backend = backend
		_path = path

	## Returns bool, matching FileAccess.store_string — the atomic-write path assigns the
	## result to a typed bool, so returning void makes the whole save fail with a type error.
	func store_string(text: String) -> bool:
		_buffer += text
		return true

	func flush() -> void:
		_backend.files[_path] = _buffer

	func close() -> void:
		_backend.files[_path] = _buffer

	func get_error() -> int:
		return OK


func open_write(path: String):
	return MemoryFile.new(self, path)


func last_open_error() -> int:
	return OK


func exists(path: String) -> bool:
	return files.has(path)


func rename(from_path: String, to_path: String) -> int:
	if not files.has(from_path):
		return ERR_FILE_NOT_FOUND
	files[to_path] = files[from_path]
	files.erase(from_path)
	return OK


func remove(path: String) -> void:
	files.erase(path)


func read_text(path: String) -> String:
	return files.get(path, "")
