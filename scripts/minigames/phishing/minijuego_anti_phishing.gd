# res://scripts/minigames/phishing/minijuego_anti_phishing.gd
extends Control

signal minijuego_completado(puntos: int)

# Nodos UI del Documento
@onready var lbl_emisor: Label = $HSplitContainer/PanelDocumento/VBox/GridHeaders/LblEmisor
@onready var lbl_asunto: Label = $HSplitContainer/PanelDocumento/VBox/GridHeaders/LblAsunto
@onready var lbl_monto: Label = $HSplitContainer/PanelDocumento/VBox/GridHeaders/LblMonto
@onready var txt_cuerpo: RichTextLabel = $HSplitContainer/PanelDocumento/VBox/TxtCuerpo
@onready var lbl_hash_impreso: Label = $HSplitContainer/PanelDocumento/VBox/LblHashImpreso
@onready var icon_ssl: TextureRect = $HSplitContainer/PanelDocumento/VBox/GridHeaders/IconSSL

# Nodos UI de Herramientas y Mando
@onready var status_hash: Label = $HSplitContainer/PanelMando/VBox/StatusHash
@onready var btn_verificar_hash: Button = $HSplitContainer/PanelMando/VBox/BtnVerificarHash
@onready var btn_aprobar: Button = $HSplitContainer/PanelMando/VBox/HBoxDecisiones/BtnAprobar
@onready var btn_rechazar: Button = $HSplitContainer/PanelMando/VBox/HBoxDecisiones/BtnRechazar

# Datos de la ronda actual
var datos_nivel: NivelPhishingArcadeData
var lista_items: Array[Dictionary] = []
var indice_item_actual: int = 0
var puntos_acumulados: int = 0

func _ready() -> void:
	btn_verificar_hash.pressed.connect(_on_btn_verificar_hash_pressed)
	btn_aprobar.pressed.connect(func(): _evaluar_decision(false)) # False = No es fraude (Aprobado)
	btn_rechazar.pressed.connect(func(): _evaluar_decision(true))  # True = Es fraude (Rechazado)

## Método de entrada llamado por MinigameFrame
func inicializar_minijuego(config_nivel: NivelBaseData) -> void:
	if config_nivel is NivelPhishingArcadeData:
		datos_nivel = config_nivel
		lista_items = datos_nivel.items_auditoria.duplicate()
		lista_items.shuffle() # Variabilidad en las rondas
		puntos_acumulados = 0
		indice_item_actual = 0
		_cargar_item_actual()

func _cargar_item_actual() -> void:
	if indice_item_actual >= lista_items.size():
		# Se terminaron los correos del lote
		minijuego_completado.emit(puntos_acumulados)
		return

	var item = lista_items[indice_item_actual]
	lbl_emisor.text = "De: " + item.get("emisor", "Desconocido")
	lbl_asunto.text = "Asunto: " + item.get("asunto", "Sin Asunto")
	lbl_monto.text = "Monto: " + item.get("monto", "$0.00")
	txt_cuerpo.text = item.get("cuerpo", "")
	lbl_hash_impreso.text = "Hash Firma: " + item.get("hash_impreso", "N/A")
	
	# Estado SSL (Verde si es válido, Rojo si no)
	var es_ssl_valido: bool = item.get("ssl_valido", true)
	icon_ssl.modulate = Color.GREEN if es_ssl_valido else Color.RED
	
	# Resetear verificador de hash
	status_hash.text = "Hash: Sin verificar"
	status_hash.modulate = Color.WHITE

func _on_btn_verificar_hash_pressed() -> void:
	var item = lista_items[indice_item_actual]
	var hash_impreso: String = item.get("hash_impreso", "")
	var hash_real: String = item.get("hash_real", "")
	
	if hash_impreso == hash_real and hash_impreso != "":
		status_hash.text = "✓ Hash Válido (Integridad Confirmada)"
		status_hash.modulate = Color.GREEN
	else:
		status_hash.text = "✗ ¡ALERTA! Firma alterada / Hash inválido"
		status_hash.modulate = Color.RED

func _evaluar_decision(jugador_marco_como_fraude: bool) -> void:
	var item = lista_items[indice_item_actual]
	var es_fraude_real: bool = item.get("es_fraude", false)
	
	if jugador_marco_como_fraude == es_fraude_real:
		# Acertó la auditoría
		puntos_acumulados += datos_nivel.puntos_por_acierto
		EventBus.puntos_actualizados.emit(puntos_acumulados) if EventBus.has_signal("puntos_actualizados") else null
	else:
		# Error de auditoría
		puntos_acumulados = max(0, puntos_acumulados - datos_nivel.penalizacion_error)
		EventBus.puntos_actualizados.emit(puntos_acumulados) if EventBus.has_signal("puntos_actualizados") else null

	# Siguiente documento
	indice_item_actual += 1
	_cargar_item_actual()
