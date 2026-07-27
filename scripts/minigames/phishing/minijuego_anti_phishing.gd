# res://scripts/minigames/phishing/minijuego_anti_phishing.gd
extends Control

signal minijuego_completado(puntos: int)

# Nodos UI del Documento
@onready var panel_documento: PanelContainer = $MainLayout/HSplitContainer/PanelDocumento
@onready var lbl_emisor: Label = $MainLayout/HSplitContainer/PanelDocumento/MarginContainer/VBoxContainer/HeaderGrid/LblEmisor
@onready var lbl_asunto: Label = $MainLayout/HSplitContainer/PanelDocumento/MarginContainer/VBoxContainer/HeaderGrid/LblAsunto
@onready var lbl_monto: Label = $MainLayout/HSplitContainer/PanelDocumento/MarginContainer/VBoxContainer/HeaderGrid/LblMonto
@onready var txt_cuerpo: RichTextLabel = $MainLayout/HSplitContainer/PanelDocumento/MarginContainer/VBoxContainer/ScrollContainer/TxtCuerpo
@onready var lbl_hash_impreso: Label = $MainLayout/HSplitContainer/PanelDocumento/MarginContainer/VBoxContainer/LblHashImpreso
@onready var icon_ssl: TextureRect = $MainLayout/HSplitContainer/PanelDocumento/MarginContainer/VBoxContainer/HeaderGrid/IconSSL

# Nodos UI de Herramientas y Consola SOC
@onready var status_hash: Label = $MainLayout/HSplitContainer/PanelMando/MarginContainer/VBoxContainer/StatusHash
@onready var btn_verificar_hash: Button = $MainLayout/HSplitContainer/PanelMando/MarginContainer/VBoxContainer/BtnVerificarHash
@onready var btn_aprobar: Button = $MainLayout/HSplitContainer/PanelDocumento/MarginContainer/VBoxContainer/HBoxDecisiones/BtnAprobar
@onready var btn_rechazar: Button = $MainLayout/HSplitContainer/PanelDocumento/MarginContainer/VBoxContainer/HBoxDecisiones/BtnRechazar
@onready var txt_console_log: RichTextLabel = $MainLayout/HSplitContainer/PanelMando/MarginContainer/VBoxContainer/TxtConsoleLog
@onready var cli_interface: LineEdit = $MainLayout/HSplitContainer/PanelMando/MarginContainer/VBoxContainer/CliInterface

# Datos de la ronda actual
var datos_nivel: NivelPhishingArcadeData
var lista_items: Array[Dictionary] = []
var indice_item_actual: int = 0
var puntos_acumulados: int = 0

# Variables de Estado para Animaciones
var verificando_hash: bool = false

func _ready() -> void:
	if btn_verificar_hash and not btn_verificar_hash.pressed.is_connected(_on_btn_verificar_hash_pressed):
		btn_verificar_hash.pressed.connect(_on_btn_verificar_hash_pressed)
	if btn_aprobar and not btn_aprobar.pressed.is_connected(_on_aprobar_pressed):
		btn_aprobar.pressed.connect(_on_aprobar_pressed)
	if btn_rechazar and not btn_rechazar.pressed.is_connected(_on_rechazar_pressed):
		btn_rechazar.pressed.connect(_on_rechazar_pressed)

	# Consola CLI (LineEdit)
	if cli_interface:
		cli_interface.text_submitted.connect(_on_cli_text_submitted)
		cli_interface.placeholder_text = "Escriba 'clear' para limpiar..."

	# Eventos e inspección interactiva en campos clave
	_configurar_inspección_y_hover(lbl_emisor, _on_emisor_gui_input)
	_configurar_inspección_y_hover(lbl_monto, _on_monto_gui_input)
	_configurar_inspección_y_hover(icon_ssl, _on_ssl_gui_input)

	if txt_cuerpo:
		txt_cuerpo.meta_clicked.connect(_on_cuerpo_meta_clicked)

## Configura señales de mouse y entrada para dar feedback hover y click
func _configurar_inspección_y_hover(nodo: Control, metodo_input: Callable) -> void:
	if not nodo: return
	nodo.mouse_filter = Control.MOUSE_FILTER_STOP
	nodo.pivot_offset = nodo.size / 2.0
	
	if not nodo.gui_input.is_connected(metodo_input):
		nodo.gui_input.connect(metodo_input)
	if not nodo.mouse_entered.is_connected(_on_elemento_mouse_entered.bind(nodo)):
		nodo.mouse_entered.connect(_on_elemento_mouse_entered.bind(nodo))
	if not nodo.mouse_exited.is_connected(_on_elemento_mouse_exited.bind(nodo)):
		nodo.mouse_exited.connect(_on_elemento_mouse_exited.bind(nodo))

## Método de entrada llamado por MinigameFrame
func inicializar_minijuego(config_nivel: NivelBaseData, _numero_nivel: int = 1) -> void:
	if config_nivel is NivelPhishingArcadeData:
		datos_nivel = config_nivel
		lista_items = datos_nivel.items_auditoria.duplicate()
		lista_items.shuffle()
		puntos_acumulados = 0
		indice_item_actual = 0
		_limpiar_consola()
		_log_console("[color=cyan]SOC MailGuard v2.4 iniciado.[/color] Monitoreando tráfico...")
		_cargar_item_actual()
	else:
		push_error("El recurso pasado a Phishing no es de tipo NivelPhishingArcadeData")

func _cargar_item_actual() -> void:
	if indice_item_actual >= lista_items.size():
		_log_console("[color=yellow]Auditoría finalizada. Generando reporte...[/color]")
		minijuego_completado.emit(puntos_acumulados)
		return

	# Transición suave al cambiar de correo
	var tween = create_tween()
	if panel_documento:
		tween.tween_property(panel_documento, "modulate:a", 0.2, 0.1)

	tween.tween_callback(func():
		var item = lista_items[indice_item_actual]
		lbl_emisor.text = "De: " + item.get("emisor", "Desconocido")
		lbl_asunto.text = "Asunto: " + item.get("asunto", "Sin Asunto")
		lbl_monto.text = "Monto: " + item.get("monto", "$0.00")
		txt_cuerpo.text = item.get("cuerpo", "")
		lbl_hash_impreso.text = "Hash Firma: " + item.get("hash_impreso", "N/A")
		
		# Estado SSL
		var es_ssl_valido: bool = item.get("ssl_valido", true)
		if icon_ssl:
			icon_ssl.modulate = Color.GREEN if es_ssl_valido else Color.RED
		
		# Resetear verificador de hash
		verificando_hash = false
		if status_hash:
			status_hash.text = "Hash: Sin verificar"
			status_hash.modulate = Color.WHITE

		_log_console("Documento #" + str(indice_item_actual + 1) + " cargado. [color=gray]Haga clic en campos para inspeccionar.[/color]")
	)

	if panel_documento:
		tween.tween_property(panel_documento, "modulate:a", 1.0, 0.15)

# --- 1. REGISTRO Y CONSOLA SOC (CLI & LOGS) ---

func _log_console(mensaje: String) -> void:
	if not txt_console_log:
		return
	var time_dict = Time.get_time_dict_from_system()
	var timestamp = "%02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second]
	txt_console_log.append_text("[%s] %s\n" % [timestamp, mensaje])

func _limpiar_consola() -> void:
	if txt_console_log:
		txt_console_log.text = ""

func _on_cli_text_submitted(cmd: String) -> void:
	var comando_limpio = cmd.strip_edges().to_lower()
	cli_interface.clear()
	
	if comando_limpio == "clear" or comando_limpio == "cls":
		_limpiar_consola()
		_log_console("[color=gray]Consola limpiada por el usuario.[/color]")
	elif comando_limpio == "help":
		_log_console("[color=yellow]Comandos disponibles:[/color] clear, help")
	elif comando_limpio != "":
		_log_console("[color=red]Comando no reconocido:[/color] " + comando_limpio)

# --- 2. HOVER Y ANIMACIONES INTERACTIVAS ---

func _on_elemento_mouse_entered(nodo: Control) -> void:
	nodo.pivot_offset = nodo.size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(nodo, "scale", Vector2(1.05, 1.05), 0.1)

func _on_elemento_mouse_exited(nodo: Control) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(nodo, "scale", Vector2.ONE, 0.1)

# --- 3. PISTAS E INSPECCIÓN INTERACTIVA ---

func _on_emisor_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if indice_item_actual >= lista_items.size(): return
		var item = lista_items[indice_item_actual]
		var emisor: String = item.get("emisor", "")
		var ssl_valido: bool = item.get("ssl_valido", true)
		
		var es_sospechoso = item.get("dominio_sospechoso", false) or not ssl_valido or "paypaI" in emisor or "crowd-strike.co" in emisor or "rrhh-net" in emisor
		
		if es_sospechoso:
			_log_console("[color=red]⚠ ANÁLISIS DNS:[/color] Dominio de " + emisor + " alterado o no certificado.")
		else:
			_log_console("[color=green]✓ ANÁLISIS DNS:[/color] Dominio de " + emisor + " verificado correctamente.")

func _on_monto_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if indice_item_actual >= lista_items.size(): return
		var item = lista_items[indice_item_actual]
		var monto: String = item.get("monto", "$0.00")
		_log_console("[color=yellow]MONITOR FINANCIERO:[/color] Solicitud de transacción por " + monto + ".")

func _on_ssl_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if indice_item_actual >= lista_items.size(): return
		var item = lista_items[indice_item_actual]
		var ssl_valido: bool = item.get("ssl_valido", true)
		if ssl_valido:
			_log_console("[color=green]✓ CERTIFICADO SSL:[/color] Válido e का emitido por una entidad de confianza.")
		else:
			_log_console("[color=red]⚠ CERTIFICADO SSL:[/color] Inválido o autorefirmado (Tráfico no seguro).")

func _on_cuerpo_meta_clicked(meta) -> void:
	_log_console("[color=red]⚠ INSPECCIÓN URL:[/color] Enlace " + str(meta) + " apunta a IP no segura.")

# --- 4. VERIFICACIÓN DE HASH CON EFECTO SCRAMBLE ---

func _on_btn_verificar_hash_pressed() -> void:
	if indice_item_actual >= lista_items.size() or verificando_hash:
		return

	verificando_hash = true
	btn_verificar_hash.disabled = true
	_log_console("Calculando checksum SHA-256...")
	
	var caracteres = "0123456789abcdef"
	var tween = create_tween()
	
	for i in range(6):
		tween.tween_callback(func():
			var temp_hash = ""
			for j in range(12):
				temp_hash += caracteres[randi() % caracteres.length()]
			status_hash.text = "Verificando: " + temp_hash
			status_hash.modulate = Color.CYAN
		)
		tween.tween_interval(0.05)
	
	tween.tween_callback(func():
		var item = lista_items[indice_item_actual]
		var hash_impreso: String = item.get("hash_impreso", "")
		var hash_real: String = item.get("hash_real", "")
		
		if hash_impreso == hash_real and hash_impreso != "":
			status_hash.text = "✓ Hash Válido (Integridad Confirmada)"
			status_hash.modulate = Color.GREEN
			_log_console("[color=green]✓ INTEGRIDAD HASH:[/color] Coincidencia de firma verificada.")
		else:
			status_hash.text = "✗ ¡ALERTA! Firma alterada / Hash inválido"
			status_hash.modulate = Color.RED
			_log_console("[color=red]✗ ALERTA HASH:[/color] Mismatch detectado. La firma fue manipulada.")
			
		btn_verificar_hash.disabled = false
		verificando_hash = false
	)

# --- 5. EVALUACIÓN Y DECISIONES ---

func _on_aprobar_pressed() -> void:
	_animar_click_boton(btn_aprobar)
	_evaluar_decision(false)

func _on_rechazar_pressed() -> void:
	_animar_click_boton(btn_rechazar)
	_evaluar_decision(true)

func _evaluar_decision(jugador_marco_como_fraude: bool) -> void:
	if indice_item_actual >= lista_items.size():
		return

	var item = lista_items[indice_item_actual]
	var es_fraude_real: bool = item.get("es_fraude", false)
	var motivo: String = item.get("motivo_fraude", "")
	
	var ptos_acierto = datos_nivel.puntos_por_acierto if datos_nivel else 100
	var ptos_error = datos_nivel.penalizacion_error if datos_nivel else 50

	var acierto = (jugador_marco_como_fraude == es_fraude_real)

	if acierto:
		puntos_acumulados += ptos_acierto
		_log_console("[color=green]DECISIÓN CORRECTA:[/color] Auditoría enviada al sistema.")
		_animar_feedback_visual(true)
	else:
		puntos_acumulados = max(0, puntos_acumulados - ptos_error)
		_log_console("[color=red]ERROR DE EVALUACIÓN:[/color] Dictamen incorrecto.")
		if motivo != "":
			_log_console("[color=yellow]MOTIVO:[/color] " + motivo)
		_animar_feedback_visual(false)
		_ejecutar_screen_shake()

	if EventBus.has_signal("puntos_actualizados"):
		EventBus.puntos_actualizados.emit(puntos_acumulados)

	get_tree().create_timer(0.35).timeout.connect(func():
		indice_item_actual += 1
		_cargar_item_actual()
	)

# --- 6. JUICE Y FEEDBACK VISUAL ---

func _animar_click_boton(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)

func _animar_feedback_visual(es_correcto: bool) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.GREEN if es_correcto else Color.RED, 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)

func _ejecutar_screen_shake() -> void:
	var pos_original = position
	var tween = create_tween()
	for i in range(4):
		var offset = Vector2(randf_range(-6, 6), randf_range(-6, 6))
		tween.tween_property(self, "position", pos_original + offset, 0.03)
	tween.tween_property(self, "position", pos_original, 0.03)
