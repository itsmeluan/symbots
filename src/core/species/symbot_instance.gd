## SymbotInstance — one Symbot the player owns (Core Design §2).
##
## The mutable half of the species/instance split: the [SpeciesDef] is authored content
## that never changes, this is the player's copy of it. It stores an id rather than the
## def, so a balance patch reaches every existing save instead of freezing a snapshot of
## the tables into each player's file.
##
## MARK AND LEVEL SHARE A CEILING. Part levels and Symbot level both cap at the current
## mark's limit (20 / 40 / 60), and Retrofit raises the cap rather than resetting
## progress — so the player never loses ground for advancing (Core Design §2.3).
class_name SymbotInstance
extends RefCounted

## Part-level and Symbot-level cap per mark. Index is mark - 1.
const MARK_CAPS: Array[int] = [20, 40, 60]
const MAX_MARK := 3

## The five fixed parts every species has (Core Design §2.4).
##
## WEAPON was removed 2026-07-20: on a fixed-species sprite a separate weapon never read
## as its own part, so it cost art effort and returned no visual identity. What a species
## fights with is now expressed by its ARMS and its skills.
enum PartSlot { CORE = 0, CHASSIS = 1, HEAD = 2, ARMS = 3, LEGS = 4 }
const PART_COUNT := 5

## Stable per-instance id. Two copies of the same species are distinct instances with
## distinct progress, so the roster keys on this and never on species_id.
var instance_id: StringName = &""
var species_id: StringName = &""

var mark: int = 1
var level: int = 1
var xp: int = 0

## Levels past the shared cap, available only to rare-and-better species. These behave
## like ordinary levels but exceed the ceiling, granting further tree points and part
## levels beyond the normal limit (Core Design §2.2).
var overclock: int = 0

## Part level per slot, indexed by PartSlot. Levelled with Scrap.
var part_levels: PackedInt32Array = PackedInt32Array([1, 1, 1, 1, 1])

## Allocated skill-tree node ids. Order is allocation order, which the respec cost model
## reads to refund most-recent-first.
var allocated_nodes: Array[StringName] = []

## Items installed into socket nodes: { node_id : item_instance_id }.
var installed_items: Dictionary = {}

## The three active skills the player has slotted. Slots 2 and 3 unlock by level; an
## unfilled slot is &"".
var active_skills: Array[StringName] = [&"", &"", &""]


func _init(p_instance_id: StringName = &"", p_species_id: StringName = &"") -> void:
	instance_id = p_instance_id
	species_id = p_species_id


## Level ceiling at the current mark, including overclock. Overclock is added on top of
## the Mk III cap only — a Mk I Symbot with overclock available still has to retrofit its
## way up before the extra levels mean anything.
func level_cap() -> int:
	var base: int = MARK_CAPS[clampi(mark, 1, MAX_MARK) - 1]
	return base + (overclock if mark >= MAX_MARK else 0)


## Part level ceiling — the same number as the Symbot cap, deliberately, so the player
## learns one scale instead of two (Core Design §2.3).
func part_level_cap() -> int:
	return level_cap()


## True when every part sits at the current mark's cap, which is the Retrofit trigger.
func can_retrofit() -> bool:
	if mark >= MAX_MARK:
		return false
	var cap: int = MARK_CAPS[mark - 1]
	for i in PART_COUNT:
		if part_levels[i] < cap:
			return false
	return true


## Advance a mark. Part levels are NOT reset — the cap rises and progress carries, so
## retrofitting is never a punishment for having invested (Core Design §2.3).
func retrofit() -> bool:
	if not can_retrofit():
		return false
	mark += 1
	return true


func get_part_level(slot: int) -> int:
	return part_levels[clampi(slot, 0, PART_COUNT - 1)]


## Raise one part by one level if the cap allows. Returns false when already capped, so
## the caller can charge Scrap only on success.
func level_up_part(slot: int) -> bool:
	var i := clampi(slot, 0, PART_COUNT - 1)
	if part_levels[i] >= part_level_cap():
		return false
	part_levels[i] += 1
	return true


## Total part levels — the Scrap-investment readout the roster screen shows, and the
## number the player compares when deciding where the next Scrap goes.
func total_part_levels() -> int:
	var sum := 0
	for i in PART_COUNT:
		sum += part_levels[i]
	return sum


## Unspent skill points: one per level gained past 1, minus what is already allocated.
## Derived rather than stored, so an allocation bug can never silently mint points.
func unspent_points() -> int:
	return maxi(0, (level - 1) - allocated_nodes.size())


func has_node(node_id: StringName) -> bool:
	return allocated_nodes.has(node_id)


## Serialisable form for the save envelope. Raw facts only — every derived value
## (stats, caps, unspent points) is recomputed on load.
func to_dict() -> Dictionary:
	return {
		"instance_id": String(instance_id),
		"species_id": String(species_id),
		"mark": mark,
		"level": level,
		"xp": xp,
		"overclock": overclock,
		"part_levels": Array(part_levels),
		"allocated_nodes": allocated_nodes.map(func(n): return String(n)),
		"installed_items": installed_items.duplicate(true),
		"active_skills": active_skills.map(func(s): return String(s)),
	}


static func from_dict(raw: Dictionary) -> SymbotInstance:
	var inst := SymbotInstance.new(
		StringName(str(raw.get("instance_id", ""))),
		StringName(str(raw.get("species_id", ""))))
	# JSON hands every number back as float; these are all integer counters and leaving
	# them as floats would poison cap comparisons downstream (ADR-0001 impl guideline).
	inst.mark = int(raw.get("mark", 1))
	inst.level = int(raw.get("level", 1))
	inst.xp = int(raw.get("xp", 0))
	inst.overclock = int(raw.get("overclock", 0))
	var lv = raw.get("part_levels", [])
	for i in mini(PART_COUNT, (lv as Array).size()):
		inst.part_levels[i] = int(lv[i])
	for n in raw.get("allocated_nodes", []):
		inst.allocated_nodes.append(StringName(str(n)))
	inst.installed_items = (raw.get("installed_items", {}) as Dictionary).duplicate(true)
	var sk = raw.get("active_skills", [])
	for i in mini(3, (sk as Array).size()):
		inst.active_skills[i] = StringName(str(sk[i]))
	return inst
