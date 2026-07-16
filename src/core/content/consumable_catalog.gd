## ConsumableCatalog — the explicit manifest of every ConsumableDef that ships in a build.
##
## Authored as a single .tres asset (assets/data/catalogs/consumable_catalog.tres).
## An entry not in this array does not exist in the game — the catalog IS the
## reviewable manifest of what ships. Directory scanning via DirAccess is forbidden
## in the content load path (ADR-0003: DirAccess returns .remap stubs in exported
## PCKs, making *.tres scans silently return nothing post-export).
##
## To add a new consumable: create its .tres file under assets/data/consumables/,
## then append the reference here. This makes the diff entry-scoped and reviewable.
##
## This is a frozen shared instance — never mutate entries at runtime (ADR-0003).
class_name ConsumableCatalog
extends Resource

## All ConsumableDef entries shipped in this build. Typed so the inspector enforces
## that only ConsumableDef resources are dragged in.
@export var entries: Array[ConsumableDef] = []
