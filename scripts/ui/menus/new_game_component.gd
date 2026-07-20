# NewGameComponent.gd
extends Control

signal character_created(data: Dictionary)
signal canceled

# Usamos rutas relativas basadas en el árbol exacto de tu escena
@onready var name_edit: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/NameEdit
@onready var surname_edit: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/SurNameEdit

@onready var pnf_option: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer4/PNFOption
@onready var role_option: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer4/RoleOption

# Referencia al PanelContainer que tiene el script de la foto
@onready var avatar_panel: PanelContainer = $MarginContainer/VBoxContainer/HBoxContainer/PanelContainer

# Botones de confirmación y regreso (ajusta las rutas a donde estén estos botones en tu escena)
# Si los tienes dentro de un contenedor en el VBoxContainer principal, puedes referenciarlos así:
@onready var button_crear: Button = $MarginContainer/VBoxContainer/HBoxContainer2/CreateButton
@onready var button_volver: Button =$MarginContainer/VBoxContainer/HBoxContainer2/BackButton
const PNFS = ["Informatica", "Electronica", "Telecomunicaciones", "Mantenimiento", "Mecanica", "Contaduria", "Administracion", "Electricidad"]
const ROLES = ["Novato", "Estudiante", "Ciberexperto"]

func _ready() -> void:
	# Inicializar los listados desplegables
	pnf_option.clear()
	for pnf in PNFS:
		pnf_option.add_item(pnf)
		
	role_option.clear()
	for role in ROLES:
		role_option.add_item(role)
		
	# Conectar señales de botones de acción
	button_crear.pressed.connect(_on_crear_pressed)
	button_volver.pressed.connect(_on_volver_pressed)

func _on_crear_pressed() -> void:
	var nombre: String = name_edit.text.strip_edges()
	var apellido: String = surname_edit.text.strip_edges()
	
	if nombre == "" or apellido == "":
		push_warning("Por favor, rellene el nombre y apellido.")
		return
		
	# Rescatamos la ruta guardada en el script del PanelContainer
	var avatar_path: String = avatar_panel.imagen_cargada_ruta
	
	var data = {
		"nombre": nombre,
		"apellido": apellido,
		"pnf": PNFS[pnf_option.selected],
		"rol": ROLES[role_option.selected],
		"avatar_path": avatar_path
	}
	
	character_created.emit(data)

func _on_volver_pressed() -> void:
	canceled.emit()

func reset_form() -> void:
	name_edit.clear()
	surname_edit.clear()
	pnf_option.selected = 0
	role_option.selected = 0
	# Le decimos al panel de la foto que vuelva a su estado por defecto
	if avatar_panel.has_method("_mostrar_estado_vacio"):
		avatar_panel._mostrar_estado_vacio()
