## BattleSfx — the battle's audio-event skeleton (UI rule: sounds trigger through an
## event system, never ad hoc).
##
## Ships with PROCEDURAL placeholder blips generated at ready time — short PCM bursts
## built in code — so the battle has tactile audio today with zero assets. When authored
## SFX arrive, they replace entries in [member _streams] and every call site is already
## wired; the audio-director owns the sound, this node owns the seam.
##
## One AudioStreamPlayer per cue so overlapping hits never cut each other off.
class_name BattleSfx
extends Node

const SAMPLE_RATE := 22050
const VOLUME_DB := -10.0

var _players: Dictionary = {}


func _ready() -> void:
	_register(&"tap", _click())
	_register(&"hit", _thud(false))
	_register(&"crit", _thud(true))
	_register(&"heal", _chime())
	_register(&"destroyed", _powerdown())


## Fire one cue by name. Unknown names are silent, not errors — a view must never crash
## over a missing sound.
func play(cue: StringName) -> void:
	var player: AudioStreamPlayer = _players.get(cue)
	if player != null:
		player.play()


func _register(cue: StringName, stream: AudioStreamWAV) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = VOLUME_DB
	add_child(player)
	_players[cue] = player


# ---------------------------------------------------------------------------
# Procedural placeholder cues
# ---------------------------------------------------------------------------

static func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


## UI tap: a 30ms filtered click.
static func _click() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.03)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var envelope := exp(-t * 180.0)
		out[i] = sin(TAU * 1250.0 * t) * envelope * 0.6
	return _make_wav(out)


## Impact: a pitch-dropping thump with a dash of noise. The crit variant is longer,
## louder and starts higher.
static func _thud(crit: bool) -> AudioStreamWAV:
	var duration := 0.16 if crit else 0.10
	var n := int(SAMPLE_RATE * duration)
	var out := PackedFloat32Array()
	out.resize(n)
	var start_hz := 340.0 if crit else 220.0
	var phase := 0.0
	# Deterministic pseudo-noise: no RNG service in the view tier.
	var noise_state := 1013904223
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / n
		var hz := lerpf(start_hz, 55.0, progress)
		phase += TAU * hz / SAMPLE_RATE
		var envelope := exp(-t * (26.0 if crit else 38.0))
		noise_state = int((noise_state * 1664525 + 1013904223) % 2147483647)
		var noise := (float(noise_state % 2000) / 1000.0 - 1.0) * 0.22 * (1.0 - progress)
		out[i] = (sin(phase) * 0.85 + noise) * envelope * (1.0 if crit else 0.8)
	return _make_wav(out)


## Repair: two soft rising sine notes.
static func _chime() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.22)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var hz := 620.0 if t < 0.10 else 830.0
		var local := t if t < 0.10 else t - 0.10
		var envelope := exp(-local * 34.0)
		out[i] = sin(TAU * hz * t) * envelope * 0.5
	return _make_wav(out)


## Destruction: a falling buzz that dies out.
static func _powerdown() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.30)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / n
		var hz := lerpf(300.0, 60.0, progress)
		phase += TAU * hz / SAMPLE_RATE
		var envelope := (1.0 - progress) * 0.55
		# A square-ish buzz reads more "machine death" than a clean sine.
		out[i] = signf(sin(phase)) * envelope * 0.5
	return _make_wav(out)
