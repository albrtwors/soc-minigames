# res://scripts/minigames/soc_td_3d/uptime_token.gd
# ============================================================
# TOKEN DE UPTIME — la moneda interactiva ($)
# ============================================================
# Brilla en el tablero donde lo generó el Servidor PDU. El jugador lo recoge
# haciendo clic encima (lo detecta soc_td_main.gd con un raycast) y suma $.
#
# CADUCIDAD:
#   - Tiene un temporizador interno: si no se recoge a tiempo, caduca y emite
#     `token_caducado` -> el controlador descuenta la disponibilidad.
#
# CÓMO SE INSTANCIA (lo hace soc_td_main.gd):
#   var t := token_scene.instantiate()
#   t.setup(pos, valor)
#   add_child(t)
extends Area3D
class_name UptimeToken

## Señales hacia el controlador.
signal token_recogido(token: Node3D)
signal token_caducado(token: Node3D)

## Valor en $ del token.
var valor: int = 25

## Segundos antes de caducar.
@export var vida_seg: float = 15.0

var _timer: Timer
var _recogido: bool = false


func setup(pos: Vector3, p_valor: int) -> void:
	global_position = pos
	valor = p_valor
	collision_layer = 4    # capa 4 = tokens (los detecta el raycast de clic)
	collision_mask = 0


func _ready() -> void:
	# Pequeño "flotado" para que se vea vivo (opcional, sin física).
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = vida_seg
	_timer.timeout.connect(_caducar)
	add_child(_timer)
	_timer.start()


func _caducar() -> void:
	if _recogido or not is_inside_tree():
		return
	_recogido = true
	token_caducado.emit(self)
	queue_free()


## Lo llama el controlador cuando el jugador hace clic sobre él.
func recoger() -> void:
	if _recogido:
		return
	_recogido = true
	if _timer:
		_timer.stop()
	token_recogido.emit(self)
	queue_free()
