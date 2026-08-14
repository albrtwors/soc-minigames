# res://scripts/minigames/soc_td_3d/defenses/server_pdu.gd
# ============================================================
# SERVIDOR PDU / MONEDAS — análogo al "Girasol"
# ============================================================
# Genera la moneda del juego: Uptimes / Presupuesto de TI ($).
#
# MECÁNICA:
#   - Cada N segundos genera un token de presupuesto brillante cerca de sí.
#   - Si no lo recoges rápido (clic), caduca y se descuenta de la disponibilidad.
#
# CÓMO FUNCIONA INTERNAMENTE:
#   - Este script NO maneja la moneda: emite la señal "token_generado"
#     con su posición y el controlador principal (soc_td_main.gd) se encarga
#     de instanciar el token en el mundo y de gestionar el presupuesto.
extends "res://scripts/minigames/soc_td_3d/defenses/base_defense_3d.gd"

## Señal hacia el controlador: "genera un token de $ en esta posición"
## (declarada en base_defense_3d.gd).

## Intervalo entre tokens (segundos).
@export var intervalo_generacion: float = 7.0

## Valor de cada token en $.
@export var valor_token: int = 25

var _timer: Timer


func _ready() -> void:
	super._ready()
	id_defensa = "server_pdu"
	hp_max = 60.0
	hp = hp_max
	costo = 50

	# Timer que dispara la generación de moneda periódicamente.
	_timer = Timer.new()
	_timer.wait_time = intervalo_generacion
	_timer.timeout.connect(_generar_token)
	add_child(_timer)
	_timer.start()


func _generar_token() -> void:
	if hp > 0.0 and is_inside_tree():
		var pos_superior := get_spawn_token_position()
		token_generado.emit(pos_superior)

## Al morir el servidor, se para la generación.
func destruir() -> void:
	if _timer:
		_timer.stop()
	super.destruir()
