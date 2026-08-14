# res://scripts/minigames/soc_td_3d/hud_soc_td.gd
# ============================================================
# HUD DEL SOC DEFENDER — "ui/hud_soc_td.tscn"
# ============================================================
# UI en CanvasLayer: cartas de servidores (selección de defensa), presupuesto
# y botón de velocidad (1x/2x).
#
# ESTRUCTURA ESPERADA (ui/hud_soc_td.tscn):
#   hud_soc_td (CanvasLayer)
#   ├── PanelToolbar (HBoxContainer)      <- cartas dinámicas de defensas
#   ├── LblPresupuesto (Label)            <- texto "$ 150"
#   ├── LblTiempo (Label)                 <- texto "01:30" (cuenta atrás)
#   └── BtnVelocidad (Button)             <- "1x" / "2x"
#
# CÓMO SE USA:
#   - El controlador llama a `construir_cartas(costos: Dictionary)`.
#   - El usuario pulsa una carta -> señal `defensa_seleccionada(id_defensa)`.
#   - El controlador llama a `set_presupuesto($)` y `set_velocidad(n)`.
extends CanvasLayer
class_name HudSocTd

## Señales hacia el controlador.
signal defensa_seleccionada(id: String)
signal velocidad_cambiada(n: int)

@onready var panel_toolbar: HBoxContainer = $PanelToolbar
@onready var lbl_presupuesto: Label = $LblPresupuesto
@onready var lbl_tiempo: Label = $LblTiempo
@onready var btn_velocidad: Button = $BtnVelocidad

var _costos: Dictionary = {}
var _id_seleccionado: String = ""
var _velocidad: int = 1


func _ready() -> void:
	if btn_velocidad:
		btn_velocidad.pressed.connect(_alternar_velocidad)


## Construye una carta por cada defensa del diccionario {id: costo}.
func construir_cartas(costos: Dictionary) -> void:
	_costos = costos
	if not panel_toolbar:
		return
	for child in panel_toolbar.get_children():
		child.queue_free()

	for id_def in _costos:
		var btn := Button.new()
		btn.text = "%s\n$%d" % [_nombre_defensa(id_def), _costos[id_def]]
		btn.custom_minimum_size = Vector2(110, 54)
		btn.pressed.connect(func(): _seleccionar(id_def))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel_toolbar.add_child(btn)


func _seleccionar(id: String) -> void:
	_id_seleccionado = id
	defensa_seleccionada.emit(id)


## Actualiza el label de presupuesto. `disponible` para saber si la carta
## seleccionada se puede pagar (por ahora solo mostramos el número).
func set_presupuesto(cant: int) -> void:
	if lbl_presupuesto:
		lbl_presupuesto.text = "$ %d" % cant


func set_velocidad(n: int) -> void:
	_velocidad = n
	if btn_velocidad:
		btn_velocidad.text = "%dx" % n


## Muestra el tiempo restante en formato MM:SS (redondeado hacia arriba).
func set_tiempo(seg: float) -> void:
	if lbl_tiempo:
		var total := maxi(0, int(ceil(seg)))
		lbl_tiempo.text = "%02d:%02d" % [total / 60, total % 60]


func _alternar_velocidad() -> void:
	_velocidad = 2 if _velocidad == 1 else 1
	set_velocidad(_velocidad)
	velocidad_cambiada.emit(_velocidad)


func _nombre_defensa(id: String) -> String:
	match id:
		"server_pdu": return "PDU"
		"firewall": return "FW"
		"wall_ids": return "IDS"
		"antivirus": return "AV"
		"honeypot": return "TRAMP"
		"ips": return "IPS"
		_: return id.to_upper()
