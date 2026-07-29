extends Node3D

signal minijuego_completado(puntos: int)

# --- CONFIGURACIÓN DESDE EL INSPECTOR ---
@export_group("Configuración de Fila y Velocidad")
## Distancia de separación en Z positivo (+Z) entre cada usuario en la fila
@export var separacion_fila_z: float = 1.5 
## Duración en segundos para el avance de la fila
@export var velocidad_avance_fila: float = 0.35
## Duración en segundos para la salida del NPC (aprobar/denegar)
@export var velocidad_salida_npc: float = 0.45

# --- NODOS DEL ÁRBOL ---
@onready var npc_spawn_point: Marker3D = $NPCSpawnPoint
@onready var npc_target_point: Marker3D = $NPCTargetPoint
@onready var ui_overlay: Control = $UI_Overlay
@onready var npc_row: Node3D = $NPCRow
@onready var npc_base: Node3D = $NPCRow/NPC if has_node("NPCRow/NPC") else null

# --- REFERENCIAS UI ---
@onready var lbl_regla: Label = ui_overlay.find_child("LblRegla", true, false) as Label
@onready var btn_permitir: Button = ui_overlay.find_child("BtnPermitir", true, false) as Button
@onready var btn_denegar: Button = ui_overlay.find_child("BtnDenegar", true, false) as Button
@onready var lbl_feedback: Label = ui_overlay.find_child("LblFeedback", true, false) as Label
@onready var feedback_overlay: Control = ui_overlay.find_child("FeedbackOverlay", true, false) as Control
@onready var flash_overlay: ColorRect = ui_overlay.find_child("FlashOverlay", true, false) as ColorRect
@onready var credential_card: Control = ui_overlay.find_child("CredentialCard", true, false) as Control

# Labels de credenciales
var lbl_nombre: Label
var lbl_email: Label
var lbl_password: Label

# --- CONFIGURACIÓN Y ESTADO ---
var puntos_por_acierto: int = 100
var penalizacion_error: int = 50
var puntos_actuales: int = 0

var lista_usuarios_turno: Array[Dictionary] = []
var indice_usuario_actual: int = 0
var nodos_npc_activos: Array[Node3D] = []

enum TipoRegla {
	MIN_LONGITUD_PASS,
	REQUIERE_ESPECIAL,
	DOMINIO_ESPECIFICO
}

# Soporte para múltiples reglas simultáneas
var reglas_activas: Array[Dictionary] = []

func _ready() -> void:
	if npc_base:
		npc_base.hide()
		
	_garantizar_labels_credenciales()
	_conectar_botones()
	
	# Fallback para pruebas independientes con F6
	get_tree().create_timer(0.1).timeout.connect(func():
		if lista_usuarios_turno.is_empty():
			_cargar_fallback_pruebas()
	)

# --- 1. HIDRATACIÓN Y UI DINÁMICA ---
func _garantizar_labels_credenciales() -> void:
	lbl_nombre = ui_overlay.find_child("LblNombre", true, false) as Label
	lbl_email = ui_overlay.find_child("LblEmail", true, false) as Label
	lbl_password = ui_overlay.find_child("LblPassword", true, false) as Label
	
	# Si no existen en la escena, creamos un panel dinámico
	if not lbl_nombre or not lbl_email or not lbl_password:
		var panel = PanelContainer.new()
		panel.name = "CredentialCard"
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		panel.position = Vector2(30, 80)
		panel.custom_minimum_size = Vector2(280, 120)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		panel.add_child(vbox)
		
		lbl_nombre = Label.new()
		lbl_nombre.name = "LblNombre"
		lbl_email = Label.new()
		lbl_email.name = "LblEmail"
		lbl_password = Label.new()
		lbl_password.name = "LblPassword"
		
		vbox.add_child(lbl_nombre)
		vbox.add_child(lbl_email)
		vbox.add_child(lbl_password)
		
		ui_overlay.add_child(panel)

func inicializar_minijuego(data_nivel: NivelArcadeData) -> void:
	puntos_actuales = 0
	indice_usuario_actual = 0
	_limpiar_fila_npcs()
	
	if "puntos_por_acierto" in data_nivel:
		puntos_por_acierto = data_nivel.puntos_por_acierto
	if "penalizacion_error" in data_nivel:
		penalizacion_error = data_nivel.penalizacion_error
		
	if "banco_usuarios" in data_nivel and data_nivel.banco_usuarios.size() > 0:
		lista_usuarios_turno = data_nivel.banco_usuarios.duplicate(true)
	else:
		_generar_usuarios_aleatorios(8)

	lista_usuarios_turno.shuffle()
	_construir_fila_visual_npcs()
	_procesar_siguiente_usuario()

func _cargar_fallback_pruebas() -> void:
	puntos_actuales = 0
	indice_usuario_actual = 0
	_generar_usuarios_aleatorios(8)
	_construir_fila_visual_npcs()
	_procesar_siguiente_usuario()

# --- 2. SISTEMA DE REGLAS DINÁMICAS Y MÚLTIPLES ---
func _generar_reglas_aleatorias_turno() -> Array[Dictionary]:
	var nuevas_reglas: Array[Dictionary] = []
	
	# Cambia dinámicamente: a veces 1 regla, a veces 2
	var cantidad_reglas = randi_range(1, 2)
	var pool_tipos = [TipoRegla.MIN_LONGITUD_PASS, TipoRegla.REQUIERE_ESPECIAL, TipoRegla.DOMINIO_ESPECIFICO]
	pool_tipos.shuffle()

	for i in range(cantidad_reglas):
		var tipo = pool_tipos.pop_back()
		match tipo:
			TipoRegla.MIN_LONGITUD_PASS:
				var min_len = [6, 8].pick_random()
				nuevas_reglas.append({
					"tipo": TipoRegla.MIN_LONGITUD_PASS,
					"parametro": min_len,
					"texto": "Contraseña debe tener al menos %d caracteres" % min_len
				})
			TipoRegla.REQUIERE_ESPECIAL:
				nuevas_reglas.append({
					"tipo": TipoRegla.REQUIERE_ESPECIAL,
					"parametro": null,
					"texto": "La contraseña DEBE incluir caracteres especiales (!@#$%^&*)"
				})
			TipoRegla.DOMINIO_ESPECIFICO:
				nuevas_reglas.append({
					"tipo": TipoRegla.DOMINIO_ESPECIFICO,
					"parametro": "@empresa.com",
					"texto": "Solo se permiten correos corporativos (@empresa.com)"
				})

	return nuevas_reglas

func _actualizar_ui_reglas() -> void:
	if not lbl_regla: return
	
	if reglas_activas.is_empty():
		lbl_regla.text = "REGLA: Permitir a todos los usuarios"
		return
		
	var textos: Array[String] = []
	for i in range(reglas_activas.size()):
		var r = reglas_activas[i]
		textos.append("%d. %s" % [i + 1, r.get("texto", "")])
		
	lbl_regla.text = "REGLAS ACTIVAS DEL TURNO:\n" + "\n".join(textos)

func _es_usuario_valido(user_data: Dictionary) -> bool:
	for regla in reglas_activas:
		var tipo = regla.get("tipo", -1)
		var param = regla.get("parametro", null)

		match tipo:
			TipoRegla.MIN_LONGITUD_PASS:
				var pwd: String = user_data.get("password", "")
				if pwd.length() < int(param): return false

			TipoRegla.REQUIERE_ESPECIAL:
				var pwd: String = user_data.get("password", "")
				var regex = RegEx.new()
				regex.compile("[!@#$%^&*(),.?\":{}|<>]")
				if regex.search(pwd) == null: return false

			TipoRegla.DOMINIO_ESPECIFICO:
				var email: String = user_data.get("email", "")
				if not email.ends_with(String(param)): return false

	return true

# --- 3. CREACIÓN Y MOVIMIENTO DE LA FILA ---
func _construir_fila_visual_npcs() -> void:
	_limpiar_fila_npcs()
	if not npc_base: return
	
	var pos_inicio = npc_base.position
	npc_base.visible = false
	
	for i in range(lista_usuarios_turno.size()):
		var nuevo_npc: Node3D = npc_base.duplicate() as Node3D
		npc_row.add_child(nuevo_npc)
		
		nuevo_npc.visible = true
		nuevo_npc.position = pos_inicio + Vector3(0, 0, i * separacion_fila_z)
		
		nodos_npc_activos.append(nuevo_npc)

func _avanzar_fila_visual() -> void:
	if not npc_base: return
	var pos_inicio = npc_base.position
	
	for i in range(nodos_npc_activos.size()):
		var npc = nodos_npc_activos[i]
		if not is_instance_valid(npc): continue
		
		var nuevo_destino = pos_inicio + Vector3(0, 0, i * separacion_fila_z)
		
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(npc, "position", nuevo_destino, velocidad_avance_fila)

func _limpiar_fila_npcs() -> void:
	for npc in nodos_npc_activos:
		if is_instance_valid(npc):
			npc.queue_free()
	nodos_npc_activos.clear()

# --- 4. GAMEPLAY Y EVALUACIÓN DINÁMICA ---
func _procesar_siguiente_usuario() -> void:
	if indice_usuario_actual >= lista_usuarios_turno.size():
		_finalizar_minijuego()
		return
		
	var datos_actuales = lista_usuarios_turno[indice_usuario_actual]
	var campos_requeridos: Array = datos_actuales.get("campos_requeridos", ["nombre", "email", "password"]).duplicate()
	
	# CAMBIO CLAVE: Asignar y cambiar reglas en CADA turno
	if datos_actuales.has("reglas_turno") and datos_actuales.reglas_turno.size() > 0:
		reglas_activas = datos_actuales.reglas_turno
	else:
		reglas_activas = _generar_reglas_aleatorias_turno()
		
	# FORZAR: los campos requeridos deben incluir lo que las reglas activas necesitan
	for regla in reglas_activas:
		match regla.get("tipo", -1):
			TipoRegla.MIN_LONGITUD_PASS, TipoRegla.REQUIERE_ESPECIAL:
				if "password" not in campos_requeridos:
					campos_requeridos.append("password")
			TipoRegla.DOMINIO_ESPECIFICO:
				if "email" not in campos_requeridos:
					campos_requeridos.append("email")
	# Siempre mostrar nombre para contexto
	if "nombre" not in campos_requeridos:
		campos_requeridos.append("nombre")
		
	_actualizar_ui_reglas()

	# Animar entrada de la tarjeta de credenciales
	_animar_entrada_credenciales()

	# Ocultar todos por defecto
	if lbl_nombre: lbl_nombre.hide()
	if lbl_email: lbl_email.hide()
	if lbl_password: lbl_password.hide()

	# Renderizar dinámicamente solo los solicitados para este turno
	if "nombre" in campos_requeridos and lbl_nombre:
		lbl_nombre.text = "Usuario: " + datos_actuales.get("nombre", "N/A")
		lbl_nombre.show()
		
	if "email" in campos_requeridos and lbl_email:
		lbl_email.text = "Email: " + datos_actuales.get("email", "N/A")
		lbl_email.show()
		
	if "password" in campos_requeridos and lbl_password:
		lbl_password.text = "Password: " + datos_actuales.get("password", "N/A")
		lbl_password.show()

	_bloquear_botones(false)

# --- 5. ANIMACIONES Y TRANSICIONES ---
func _animar_entrada_credenciales() -> void:
	if not credential_card: return
	credential_card.modulate = Color(1, 1, 1, 0)
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(credential_card, "modulate", Color(1, 1, 1, 1), 0.35)

func _flash_pantalla(color: Color) -> void:
	if not flash_overlay: return
	flash_overlay.color = color
	flash_overlay.modulate.a = 0.35
	var tween = create_tween()
	tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)

# --- 6. EVALUACIÓN ---
func _on_decision_tomada(permitir_acceso: bool) -> void:
	_bloquear_botones(true)
	
	var datos_actuales = lista_usuarios_turno[indice_usuario_actual]
	var es_valido = _es_usuario_valido(datos_actuales)
	var decision_correcta = (permitir_acceso == es_valido)
	
	if decision_correcta:
		puntos_actuales += puntos_por_acierto
		_flash_pantalla(Color(0.1, 0.9, 0.2, 1))
		_mostrar_feedback("¡ACCESO CORRECTO! +" + str(puntos_por_acierto) + " PTS", Color(0.2, 0.9, 0.3, 1))
	else:
		puntos_actuales = max(0, puntos_actuales - penalizacion_error)
		_flash_pantalla(Color(1, 0.15, 0.15, 1))
		_mostrar_feedback("¡ERROR DE SEGURIDAD! - " + str(penalizacion_error) + " PTS", Color(1, 0.2, 0.2, 1))

	if EventBus.has_signal("puntos_actualizados"):
		EventBus.puntos_actualizados.emit(puntos_actuales)

	if nodos_npc_activos.size() > 0:
		var npc_atendido = nodos_npc_activos.pop_at(0)
		_animar_salida_npc(npc_atendido, permitir_acceso)

	indice_usuario_actual += 1
	
	get_tree().create_timer(velocidad_salida_npc).timeout.connect(func():
		_avanzar_fila_visual()
		_procesar_siguiente_usuario()
	)

func _animar_salida_npc(npc: Node3D, permitido: bool) -> void:
	if not is_instance_valid(npc): return
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var pos_actual = npc.global_position
	
	if permitido:
		var destino_aprobar = pos_actual + Vector3(0, 0, -6.0)
		tween.tween_property(npc, "global_position", destino_aprobar, velocidad_salida_npc)
		tween.tween_property(npc, "scale", Vector3.ZERO, velocidad_salida_npc)
	else:
		var destino_rechazar = pos_actual + Vector3(-2.5, 0, 2.0)
		tween.tween_property(npc, "global_position", destino_rechazar, velocidad_salida_npc)
		tween.tween_property(npc, "scale", Vector3.ZERO, velocidad_salida_npc)
		
	tween.finished.connect(npc.queue_free)

func _mostrar_feedback(texto: String, color: Color) -> void:
	if not feedback_overlay or not lbl_feedback: return
	
	lbl_feedback.text = texto
	lbl_feedback.modulate = color
	
	feedback_overlay.modulate = Color(1, 1, 1, 0)
	feedback_overlay.scale = Vector2(0.7, 0.7)
	feedback_overlay.show()
	
	var tween_in = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween_in.set_parallel(true)
	tween_in.tween_property(feedback_overlay, "modulate", Color(1, 1, 1, 1), 0.3)
	tween_in.tween_property(feedback_overlay, "scale", Vector2(1, 1), 0.3)
	
	get_tree().create_timer(1.2).timeout.connect(func():
		if not feedback_overlay: return
		var tween_out = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween_out.set_parallel(true)
		tween_out.tween_property(feedback_overlay, "modulate", Color(1, 1, 1, 0), 0.25)
		tween_out.tween_property(feedback_overlay, "scale", Vector2(0.85, 0.85), 0.25)
		tween_out.finished.connect(func():
			if feedback_overlay: feedback_overlay.hide()
		)
	)

func _finalizar_minijuego() -> void:
	_bloquear_botones(true)
	minijuego_completado.emit(puntos_actuales)

# --- 7. AUXILIARES Y GENERACIÓN DE PRUEBAS ---
func _conectar_botones() -> void:
	if btn_permitir and not btn_permitir.pressed.is_connected(_on_permitir_pressed):
		btn_permitir.pressed.connect(_on_permitir_pressed)
	if btn_denegar and not btn_denegar.pressed.is_connected(_on_denegar_pressed):
		btn_denegar.pressed.connect(_on_denegar_pressed)

func _on_permitir_pressed() -> void:
	_on_decision_tomada(true)

func _on_denegar_pressed() -> void:
	_on_decision_tomada(false)

func _bloquear_botones(bloquear: bool) -> void:
	if btn_permitir: btn_permitir.disabled = bloquear
	if btn_denegar: btn_denegar.disabled = bloquear

func _generar_usuarios_aleatorios(cantidad: int) -> void:
	lista_usuarios_turno.clear()
	var nombres = ["Carlos R.", "Ana M.", "Bot_32", "Admin_Test", "Lucia P.", "Guest_99", "User_Hacker"]
	var dominios = ["@empresa.com", "@tempmail.net", "@hacker.ru"]
	var passwords_ejemplo = ["Admin1234!", "123", "Pass_2026!", "carlos123", "Secure#99"]
	
	var opciones_campos = [
		["nombre"],
		["email"],
		["password"],
		["nombre", "email"],
		["email", "password"],
		["nombre", "password"],
		["nombre", "email", "password"]
	]

	for i in range(cantidad):
		lista_usuarios_turno.append({
			"nombre": nombres.pick_random(),
			"email": str(randi() % 100) + dominios.pick_random(),
			"password": passwords_ejemplo.pick_random(),
			"campos_requeridos": opciones_campos.pick_random()
		})
