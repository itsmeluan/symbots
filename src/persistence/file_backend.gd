## FileBackend — the real disk seam behind SaveLoadService (ADR-0001).
##
## A thin wrapper around `FileAccess`/`DirAccess` so the atomic-write failure
## paths (open-error, `store_string` bool false, post-write `get_error`) are
## GUT-testable via a fake backend, without a real full disk or sandbox denial.
##
## IMPORTANT (ptrcall gotcha, see project memory): callers must hold the returned
## handle and this backend as **untyped** vars so calls dispatch through Variant,
## not statically-typed ptrcall — otherwise a fake's overrides would be bypassed.
## `FileAccess` itself is the handle here (it exposes store_string/get_error/
## flush/close); the fake supplies a duck-typed stand-in.
class_name FileBackend
extends RefCounted

var _last_open_error: int = OK


## Open `path` for writing. Returns the handle (a `FileAccess`), or `null` on
## failure — after which `last_open_error()` carries the reason. Hold the result
## untyped.
func open_write(path: String):
	var fa := FileAccess.open(path, FileAccess.WRITE)
	_last_open_error = FileAccess.get_open_error()
	return fa


## The error from the most recent `open_write()` (OK if it succeeded).
func last_open_error() -> int:
	return _last_open_error


## True if a file exists at `path`.
func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


## Atomic rename (POSIX `rename(2)` within a single APFS `user://` volume,
## per ADR-0001). Returns an Error code.
func rename(from_path: String, to_path: String) -> int:
	return DirAccess.rename_absolute(from_path, to_path)


## Remove a file (used to discard a failed `.tmp`).
func remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Read a file's full text, or "" if it cannot be opened. Used by the load path
## (SL-5). Hold the caller-side result untyped is not required for reads.
func read_text(path: String) -> String:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return ""
	var text := fa.get_as_text()
	fa.close()
	return text
