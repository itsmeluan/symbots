@tool
extends VBoxContainer

# --- ELEMENTI DELL'INTERFACCIA ---
var menu_lingua: OptionButton
var titolo: Label
var lbl_nome: Label
var input_nome: LineEdit
var lbl_opzioni: Label
var check_script_unico: CheckBox
var check_include_dash: CheckBox
var btn_topdown: Button
var btn_platformer: Button

# Percorsi di base
const CARTELLA_SCRIPT = "res://scripts/generated/"

# --- DATABASE DELLE TRADUZIONI ---
var lingua_corrente = "en" # Di default parte in inglese per lo store globale

const TRADUZIONI = {
	"en": {
		"titolo": "⚙️ MODULAR PRO GENERATOR",
		"lbl_nome": "Node Name:",
		"lbl_opzioni": "Options & Components:",
		"check_script": "Save as Unique Script (*.gd)",
		"check_dash": "Include Dash Mechanic (Shift)",
		"btn_topdown": "⚡ Generate Top-Down",
		"btn_platformer": "🧱 Generate Platformer",
		"errore_scena": "Please open a scene first!",
		"azione_undo": "Generate "
	},
	"it": {
		"titolo": "⚙️ GENERATORE PRO MODULARE",
		"lbl_nome": "Nome del Nodo:",
		"lbl_opzioni": "Opzioni e Componenti:",
		"check_script": "Salva come Script Unico (*.gd)",
		"check_dash": "Includi Meccanica Dash (Shift)",
		"btn_topdown": "⚡ Genera Top-Down",
		"btn_platformer": "🧱 Genera Platformer",
		"errore_scena": "Per favore, apri prima una scena!",
		"azione_undo": "Genera "
	}
}

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(200, 0)
	
	# --- 1. SELETTORE LINGUA (IN CIMA) ---
	var container_lingua = HBoxContainer.new()
	var lbl_lang = Label.new()
	lbl_lang.text = "🌐 Language:"
	container_lingua.add_child(lbl_lang)
	
	menu_lingua = OptionButton.new()
	menu_lingua.add_item("English", 0)
	menu_lingua.add_item("Italiano", 1)
	menu_lingua.selected = 0 # English selezionato di base
	menu_lingua.item_selected.connect(_on_lingua_cambiata)
	container_lingua.add_child(menu_lingua)
	
	add_child(container_lingua)
	add_child(HSeparator.new())
	
	# --- 2. CREAZIONE DI TUTTI I COMPONENTI UI ---
	titolo = Label.new()
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titolo.add_theme_font_size_override("font_size", 14)
	add_child(titolo)
	
	add_child(HSeparator.new())
	
	lbl_nome = Label.new()
	lbl_nome.add_theme_color_override("font_color", Color.DARK_GRAY)
	add_child(lbl_nome)
	
	input_nome = LineEdit.new()
	input_nome.text = "EroeGenerato"
	add_child(input_nome)
	
	add_child(HSeparator.new())
	
	lbl_opzioni = Label.new()
	lbl_opzioni.add_theme_color_override("font_color", Color.DARK_GRAY)
	add_child(lbl_opzioni)
	
	check_script_unico = CheckBox.new()
	check_script_unico.button_pressed = true
	add_child(check_script_unico)
	
	check_include_dash = CheckBox.new()
	check_include_dash.button_pressed = false
	add_child(check_include_dash)
	
	add_child(HSeparator.new())
	
	btn_topdown = Button.new()
	btn_topdown.pressed.connect(func(): _avvia_generazione(false))
	add_child(btn_topdown)
	
	btn_platformer = Button.new()
	btn_platformer.pressed.connect(func(): _avvia_generazione(true))
	add_child(btn_platformer)
	
	# Applica la lingua iniziale
	_aggiorna_testi_interfaccia()

# --- FUNZIONE DI AGGIORNAMENTO IN TEMPO REALE ---
func _on_lingua_cambiata(index: int) -> void:
	if index == 0:
		lingua_corrente = "en"
	elif index == 1:
		lingua_corrente = "it"
	
	_aggiorna_testi_interfaccia()

func _aggiorna_testi_interfaccia() -> void:
	var t = TRADUZIONI[lingua_corrente]
	
	titolo.text = t["titolo"]
	lbl_nome.text = t["lbl_nome"]
	lbl_opzioni.text = t["lbl_opzioni"]
	check_script_unico.text = t["check_script"]
	check_include_dash.text = t["check_dash"]
	btn_topdown.text = t["btn_topdown"]
	btn_platformer.text = t["btn_platformer"]

# ============================================================
# LOGICA DI GENERAZIONE (CON STRINGHE TRADOTTE)
# ============================================================
func _avvia_generazione(usa_gravita: bool):
	var root_scena = EditorInterface.get_edited_scene_root()
	var t = TRADUZIONI[lingua_corrente]
	
	if not root_scena: 
		push_warning(t["errore_scena"])
		return

	_garantisci_struttura_cartelle()
	
	var nome_nodo_pulito = input_nome.text.strip_edges()
	if nome_nodo_pulito.is_empty(): 
		nome_nodo_pulito = "Platformer" if usa_gravita else "TopDown"

	var path_script: String
	var nome_finalizzato = nome_nodo_pulito

	if check_script_unico.button_pressed:
		var base_filename = nome_nodo_pulito.to_snake_case()
		path_script = CARTELLA_SCRIPT + base_filename + ".gd"
		
		var contatore = 1
		while FileAccess.file_exists(path_script) or root_scena.has_node(nome_finalizzato):
			contatore += 1
			path_script = CARTELLA_SCRIPT + base_filename + "_" + str(contatore) + ".gd"
			nome_finalizzato = nome_nodo_pulito + "_" + str(contatore)
	else:
		var tipo = "platformer" if usa_gravita else "topdown"
		var variante = "_con_dash" if check_include_dash.button_pressed else "_base"
		path_script = CARTELLA_SCRIPT + tipo + variante + ".gd"
		
		var contatore = 1
		while root_scena.has_node(nome_finalizzato):
			contatore += 1
			nome_finalizzato = nome_nodo_pulito + "_" + str(contatore)

	var script_risorsa = _compila_e_salva_script(path_script, usa_gravita, check_include_dash.button_pressed)
	if not script_risorsa: return

	var character = CharacterBody2D.new()
	character.name = nome_finalizzato
	character.set_script(script_risorsa)

	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	if FileAccess.file_exists("res://icon.svg"):
		sprite.texture = load("res://icon.svg")
	character.add_child(sprite)

	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	collision.shape = shape
	character.add_child(collision)

	# L'azione dell'Undo/Redo usa il prefisso tradotto correttamente
	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action(t["azione_undo"] + nome_finalizzato)
	undo_redo.add_do_method(root_scena, "add_child", character)
	undo_redo.add_do_reference(character)
	undo_redo.add_do_property(character, "owner", root_scena)
	undo_redo.add_do_property(sprite, "owner", root_scena)
	undo_redo.add_do_property(collision, "owner", root_scena)
	undo_redo.add_undo_method(root_scena, "remove_child", character)
	undo_redo.commit_action()

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(character)

# ============================================================
# COMPILATORE CODICE SORGENTE (INGLÈSE DI DEFAULT)
# ============================================================
func _garantisci_struttura_cartelle():
	if not DirAccess.dir_exists_absolute(CARTELLA_SCRIPT):
		DirAccess.make_dir_recursive_absolute(CARTELLA_SCRIPT)

func _compila_e_salva_script(path: String, usa_gravita: bool, con_dash: bool) -> GDScript:
	if not check_script_unico.button_pressed and ResourceLoader.exists(path):
		return load(path) as GDScript
		
	# NOTA COMMERCIALE: Il codice generato negli script finali rimane in inglese standard (speed, gravity, ecc.)
	# poiché le API di Godot e le best-practice di programmazione internazionali richiedono l'inglese.
	var sorgente = "extends CharacterBody2D\n\n"
	
	sorgente += "@export var speed: float = 300.0\n"
	if usa_gravita:
		sorgente += "@export var jump_velocity: float = -400.0\n"
		sorgente += "@export var gravity: float = 980.0\n"
	
	if con_dash:
		sorgente += "@export var dash_speed: float = 600.0\n"
	
	sorgente += "\n"
	
	if usa_gravita:
		sorgente += "func _physics_process(delta):\n"
		sorgente += "	if not is_on_floor():\n"
		sorgente += "		velocity.y += gravity * delta\n\n"
		sorgente += "	if Input.is_action_just_pressed(\"ui_accept\") and is_on_floor():\n"
		sorgente += "		velocity.y = jump_velocity\n\n"
		sorgente += "	var direction = Input.get_axis(\"ui_left\", \"ui_right\")\n"
		
		if con_dash:
			sorgente += "	var current_speed = dash_speed if Input.is_key_pressed(KEY_SHIFT) else speed\n"
			sorgente += "	if direction:\n"
			sorgente += "		velocity.x = direction * current_speed\n"
		else:
			sorgente += "	if direction:\n"
			sorgente += "		velocity.x = direction * speed\n"
			
		sorgente += "	else:\n"
		sorgente += "		velocity.x = move_toward(velocity.x, 0, speed)\n"
		sorgente += "	move_and_slide()\n"
	else:
		sorgente += "func _physics_process(_delta):\n"
		sorgente += "	var input_direction = Input.get_vector(\"ui_left\", \"ui_right\", \"ui_up\", \"ui_down\")\n"
		
		if con_dash:
			sorgente += "	var current_speed = dash_speed if Input.is_key_pressed(KEY_SHIFT) else speed\n"
			sorgente += "	velocity = input_direction * current_speed\n"
		else:
			sorgente += "	velocity = input_direction * speed\n"
			
		sorgente += "	move_and_slide()\n"

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(sorgente)
		file.close()
	else:
		return null
	
	if EditorInterface: 
		EditorInterface.get_resource_filesystem().update_file(path)
		
	var script_caricato = load(path) as GDScript
	if script_caricato:
		script_caricato.reload()
		return script_caricato
		
	return null