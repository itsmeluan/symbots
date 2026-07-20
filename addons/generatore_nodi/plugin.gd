@tool
extends EditorPlugin

const GEN_DOCK = preload("res://addons/generatore_nodi/generator_dock.gd")
var dock_instance: Control

func _enter_tree() -> void:
	# Istanzia l'interfaccia del menu
	dock_instance = GEN_DOCK.new()
	dock_instance.name = "Generatore Nodi"
	
	# Aggiunge il menu al pannello laterale destro (in basso vicino all'Ispettore)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock_instance)

func _exit_tree() -> void:
	# Rimuove il menu in modo pulito quando il plugin viene disattivato
	if dock_instance:
		remove_control_from_docks(dock_instance)
		dock_instance.queue_free()