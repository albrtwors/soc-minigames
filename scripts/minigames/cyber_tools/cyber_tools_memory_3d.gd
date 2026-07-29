extends Node3D

signal minijuego_completado(puntos: int)

@export var card_scene: PackedScene

var grid_filas: int = 3
var grid_columnas: int = 4
var puntos_por_acierto: int = 100
var penalizacion_error: int = 25
var banco_herramientas: Array[Dictionary] = []

var cartas_reveladas: Array[Node] = []
var pares_encontrados: int = 0
var puntos_actuales: int = 0
var procesando_evaluacion: bool = false
var total_pares: int = 0

const ESPACIO_X: float = 0.035
const ESPACIO_Z: float = 0.045

func _ready() -> void:
	_setup_camara_y_luz()
	_cargar_banco_predeterminado()
	if card_scene:
		generar_tablero()

func _setup_camara_y_luz() -> void:
	var cam = $Camera3D
	if cam:
		cam.position = Vector3(0, 0.3, 0.01)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 0.15
		cam.near = 0.2
		cam.far = 10.0
	var luz = $DirectionalLight3D
	if luz:
		luz.position = Vector3(0, 5, 0)
		luz.rotation_degrees = Vector3(-90, 0, 0)

func inicializar_minijuego(data_nivel: NivelArcadeData) -> void:
	puntos_actuales = 0
	pares_encontrados = 0
	cartas_reveladas.clear()
	procesando_evaluacion = false

	if data_nivel is NivelCyberToolsData:
		puntos_por_acierto = data_nivel.puntos_por_acierto
		penalizacion_error = data_nivel.penalizacion_error
		grid_filas = data_nivel.grid_filas
		grid_columnas = data_nivel.grid_columnas
		banco_herramientas = data_nivel.banco_herramientas.duplicate(true)
	else:
		_cargar_banco_predeterminado()

	_limpiar_tablero()
	generar_tablero()

func generar_tablero() -> void:
	if not card_scene:
		return

	var contenedor = $GridSlots
	if not contenedor:
		contenedor = Node3D.new()
		contenedor.name = "GridSlots"
		add_child(contenedor)

	_limpiar_tablero()

	total_pares = (grid_filas * grid_columnas) / 2
	if banco_herramientas.is_empty():
		_cargar_banco_predeterminado()
	banco_herramientas.shuffle()

	var herramientas = banco_herramientas.slice(0, total_pares)

	var datos_nombres: Array[Dictionary] = []
	var datos_descripciones: Array[Dictionary] = []

	for tool in herramientas:
		datos_nombres.append({"id": tool.get("id", 0), "es_concepto": false, "texto": tool.get("nombre", "")})
		datos_descripciones.append({"id": tool.get("id", 0), "es_concepto": true, "texto": tool.get("descripcion", "")})

	datos_nombres.shuffle()
	datos_descripciones.shuffle()

	var centro_x = (total_pares - 1) * ESPACIO_X * 0.5

	for i in total_pares:
		var x_pos = i * ESPACIO_X - centro_x
		_instanciar_carta(datos_nombres[i], Vector3(x_pos, 0.001, -ESPACIO_Z * 0.5))
		_instanciar_carta(datos_descripciones[i], Vector3(x_pos, 0.001, ESPACIO_Z * 0.5))

func _instanciar_carta(data: Dictionary, pos: Vector3) -> Node:
	var card = card_scene.instantiate()
	$GridSlots.add_child(card)
	card.position = pos
	card.scale = Vector3(0.8, 0.8, 0.8)
	card.rotation_degrees = Vector3(0.0, 0.0, 0.0)

	if card.has_method("setup"):
		card.setup(data["id"], data["es_concepto"], data["texto"])
	if card.has_signal("carta_levantada"):
		card.carta_levantada.connect(_on_carta_levantada)
	if card.has_signal("carta_bajada"):
		card.carta_bajada.connect(_on_carta_bajada)

	return card

func _limpiar_tablero() -> void:
	var contenedor = $GridSlots
	if not contenedor:
		return
	for child in contenedor.get_children():
		child.queue_free()

func _on_carta_levantada(carta: Node) -> void:
	if procesando_evaluacion:
		return
	if not carta or carta in cartas_reveladas:
		return
	cartas_reveladas.append(carta)
	if cartas_reveladas.size() == 2:
		_evaluar_par()

func _on_carta_bajada(carta: Node) -> void:
	if procesando_evaluacion:
		return
	if carta:
		cartas_reveladas.erase(carta)

func _evaluar_par() -> void:
	procesando_evaluacion = true
	var c1 = cartas_reveladas[0]
	var c2 = cartas_reveladas[1]

	var c1_id = c1.get("id_par") if "id_par" in c1 else -1
	var c2_id = c2.get("id_par") if "id_par" in c2 else -2
	var c1_concepto = c1.get("es_tarjeta_concepto") if "es_tarjeta_concepto" in c1 else false
	var c2_concepto = c2.get("es_tarjeta_concepto") if "es_tarjeta_concepto" in c2 else false

	var es_par_valido = (c1_id == c2_id) and (c1_concepto != c2_concepto)

	if es_par_valido:
		puntos_actuales += puntos_por_acierto
		pares_encontrados += 1

		if c1.has_method("animar_resultado"):
			c1.animar_resultado(true)
		if c2.has_method("animar_resultado"):
			c2.animar_resultado(true)

		cartas_reveladas.clear()
		get_tree().create_timer(0.4).timeout.connect(func():
			procesando_evaluacion = false
		)

		_emitir_puntos()

		if pares_encontrados >= total_pares:
			minijuego_completado.emit(puntos_actuales)
	else:
		puntos_actuales = max(0, puntos_actuales - penalizacion_error)
		_emitir_puntos()

		get_tree().create_timer(0.7).timeout.connect(func():
			if c1.has_method("animar_resultado"):
				c1.animar_resultado(false)
			if c2.has_method("animar_resultado"):
				c2.animar_resultado(false)
			get_tree().create_timer(0.3).timeout.connect(func():
				cartas_reveladas.clear()
				procesando_evaluacion = false
			)
		)

func _emitir_puntos() -> void:
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		if bus.has_signal("puntos_actualizados"):
			bus.puntos_actualizados.emit(puntos_actuales)

func _cargar_banco_predeterminado() -> void:
	var nivel_data = load("res://scripts/data/cyber_tools_levels/nivel_1.tres") as NivelCyberToolsData
	if nivel_data:
		puntos_por_acierto = nivel_data.puntos_por_acierto
		penalizacion_error = nivel_data.penalizacion_error
		grid_filas = nivel_data.grid_filas
		grid_columnas = nivel_data.grid_columnas
		banco_herramientas = nivel_data.banco_herramientas.duplicate(true)
	else:
		banco_herramientas = [
			{"id": 0, "nombre": "Wireshark", "descripcion": "Analizador de tráfico de red."},
			{"id": 1, "nombre": "Nmap", "descripcion": "Escáner de puertos y servicios."},
			{"id": 2, "nombre": "Metasploit", "descripcion": "Framework para pruebas de exploits."},
			{"id": 3, "nombre": "Burp Suite", "descripcion": "Auditoría de seguridad web."},
			{"id": 4, "nombre": "Snort", "descripcion": "IDS/IPS basado en reglas."},
			{"id": 5, "nombre": "Hashcat", "descripcion": "Descifrado de hashes."}
		]
