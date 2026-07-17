## Fake file backend — an in-memory filesystem with scripted failure injection,
## used by SL-3..SL-6 to drive the atomic-write failure/corruption paths
## deterministically (no real full disk / sandbox denial needed).
##
## preload()-ed, NOT class_name (a class_name in tests/ would pollute the global
## registry). Duck-types FileBackend: open_write/last_open_error/exists/rename/
## remove/read_text. Held untyped by the service (Variant dispatch), so its
## overrides are honored (ptrcall gotcha avoided).
extends RefCounted

## path -> content string (the in-memory FS)
var files: Dictionary = {}
## recorded call sequence across handles ("store"/"flush"/"close")
var call_log: Array = []

var _last_open_error: int = OK

# --- failure injection knobs ---
var fail_open: bool = false          ## open_write() returns null
var fail_store_bool: bool = false    ## handle.store_string() returns false
var fail_get_error: int = OK         ## handle.get_error() returns this (post-write)
var fail_rename: bool = false        ## rename() returns a non-OK error


func open_write(path: String):
	if fail_open:
		_last_open_error = ERR_CANT_OPEN
		return null
	_last_open_error = OK
	return FakeHandle.new(self, path)


func last_open_error() -> int:
	return _last_open_error


func exists(path: String) -> bool:
	return files.has(path)


func rename(from_path: String, to_path: String) -> int:
	if fail_rename:
		return FAILED
	if not files.has(from_path):
		return ERR_FILE_NOT_FOUND
	files[to_path] = files[from_path]   # overwrites target → one-generation .bak
	files.erase(from_path)
	return OK


func remove(path: String) -> void:
	files.erase(path)


func read_text(path: String) -> String:
	return files.get(path, "")


## Test convenience — seed a file directly (e.g. a pre-existing prior save).
func seed_file(path: String, content: String) -> void:
	files[path] = content


class FakeHandle extends RefCounted:
	var _backend
	var _path: String
	var _buffer: String = ""
	func _init(backend, path: String) -> void:
		_backend = backend
		_path = path
	func store_string(s: String) -> bool:
		_buffer = s
		_backend.call_log.append("store")
		return not _backend.fail_store_bool
	func get_error() -> int:
		return _backend.fail_get_error
	func flush() -> void:
		_backend.call_log.append("flush")
	func close() -> void:
		_backend.call_log.append("close")
		# a real FS leaves the tmp file present after close even on a failed
		# store; the service's remove() discards it on the failure path
		_backend.files[_path] = _buffer
