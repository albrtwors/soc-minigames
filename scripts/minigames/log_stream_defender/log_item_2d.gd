# res://scripts/minigames/log_stream_defender/log_item_2d.gd
extends Panel

## Log individual que cae por un carril (versión 2D).
## Lo instancia y configura LogStreamDefender2D.

signal log_perdido(log_item: Control)

var texto: String = ""
var respuesta_correcta: int = 0
var velocidad_caida: float = 0.0
var limite_y: float = 0.0
var esta_procesado: bool = false

var _tween: Tween

@onready var lbl_texto: Label = $MarginContainer/Label

func setup(texto_log: String, respuesta: int, velocidad: float, limite: float) -> void:
	texto = texto_log
	respuesta_correcta = respuesta
	velocidad_caida = velocidad
	limite_y = limite
	pivot_offset = size / 2.0
	if lbl_texto:
		lbl_texto.text = texto_log

func _process(delta: float) -> void:
	if esta_procesado:
		return
	position.y += velocidad_caida * delta
	if position.y > limite_y:
		esta_procesado = true
		log_perdido.emit(self)

## Congela el log donde esté. Se llama al terminar la partida para
## detener el flujo de datos (ningún log sigue cayendo ni emite log_perdido).
func detener() -> void:
	if esta_procesado:
		return
	esta_procesado = true
	set_process(false)

func destruir_con_exito() -> void:
	_animar_resultado(Color(0.1, 0.4, 0.18), Color(0.15, 0.9, 0.3, 1), true)

func destruir_con_error() -> void:
	_animar_resultado(Color(0.45, 0.1, 0.1), Color(1.0, 0.2, 0.2, 1), false)

func _animar_resultado(bg_color: Color, border_color: Color, exito: bool) -> void:
	if esta_procesado:
		return
	esta_procesado = true
	set_process(false)

	if _tween:
		_tween.kill()

	var sb := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	sb.bg_color = bg_color
	sb.border_color = border_color
	add_theme_stylebox_override("panel", sb)

	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.set_parallel(true)
	if exito:
		_tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.1)
	else:
		_tween.chain().tween_property(self, "position:x", position.x + 8.0, 0.05)
		_tween.chain().tween_property(self, "position:x", position.x - 8.0, 0.1)
		_tween.chain().tween_property(self, "position:x", position.x, 0.05)
	_tween.chain().tween_property(self, "scale", Vector2.ZERO, 0.3)
	_tween.chain().tween_callback(queue_free)
