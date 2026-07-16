## EnemyCatalog — the explicit manifest of every EnemyDef that ships in a build.
##
## Authored as a single .tres asset (assets/data/catalogs/enemy_catalog.tres).
## An entry not in this array does not exist in the game — the catalog IS the
## reviewable manifest of what ships. Directory scanning via DirAccess is forbidden
## in the content load path (ADR-0003: DirAccess returns .remap stubs in exported
## PCKs, making *.tres scans silently return nothing post-export).
##
## To add a new enemy: create its .tres file under assets/data/enemies/, then
## append the reference here. This makes the diff entry-scoped and always reviewable.
##
## This is a frozen shared instance — never mutate entries at runtime (ADR-0003).
class_name EnemyCatalog
extends Resource

## All EnemyDef entries shipped in this build. Typed so the inspector enforces
## that only EnemyDef resources are dragged in.
@export var entries: Array[EnemyDef] = []
