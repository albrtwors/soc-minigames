extends PanelContainer

# --- PROPIEDADES ACCESIBLES DESDE OTROS SCRIPTS ---
# Guarda la textura actual de la imagen. Si no hay imagen, será null.
var textura_actual: Texture2D = null
# Guarda la ruta del archivo por si la necesitas para guardar la partida/perfil
var imagen_cargada_ruta: String = ""

# Nodos referenciados de tu escena
@onready var button_cargar: Button = $MarginContainer/Control/Button
@onready var texture_rect: TextureRect = $MarginContainer/Control/TextureRect
@onready var btn_eliminar: Button = $MarginContainer/Control/Button2

# Explorador de archivos nativo
var file_dialog: FileDialog

func _ready() -> void:
	# Inicializar el FileDialog nativo
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.png, *.jpg, *.jpeg ; Imágenes"]
	file_dialog.use_native_dialog = true
	add_child(file_dialog)
	
	# Conectar las señales
	button_cargar.pressed.connect(_on_button_cargar_pressed)
	btn_eliminar.pressed.connect(_on_btn_eliminar_pressed)
	file_dialog.file_selected.connect(_on_imagen_seleccionada)
	
	# Estado inicial de la UI
	_mostrar_estado_vacio()

func _on_button_cargar_pressed() -> void:
	if imagen_cargada_ruta == "":
		file_dialog.popup()

func _on_imagen_seleccionada(path: String) -> void:
	var img = Image.load_from_file(path)
	if img:
		var tex = ImageTexture.create_from_image(img)
		texture_rect.texture = tex
		
		# --- Guardamos el valor para accesos externos ---
		textura_actual = tex
		imagen_cargada_ruta = path
		
		_mostrar_estado_con_imagen()

func _on_btn_eliminar_pressed() -> void:
	_mostrar_estado_vacio()

# ESTADO 1: Sin imagen
func _mostrar_estado_vacio() -> void:
	imagen_cargada_ruta = ""
	textura_actual = null # Reseteamos para que otros scripts sepan que está vacío
	texture_rect.texture = null
	
	button_cargar.visible = true
	button_cargar.text = "Añade una imagen"
	btn_eliminar.visible = false

# ESTADO 2: Con imagen
func _mostrar_estado_con_imagen() -> void:
	button_cargar.visible = false
	btn_eliminar.visible = true
