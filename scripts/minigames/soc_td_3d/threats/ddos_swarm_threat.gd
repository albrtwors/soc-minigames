# res://scripts/minigames/soc_td_3d/threats/ddos_swarm_threat.gd
# ============================================================
# DDoS SWARM — enjambre / botnet
# ============================================================
# Múltiples humanoides pequeños alineados en grupo (botnet): mucho volumen
# de tráfico = mucha vida. Avanzan en ráfagas: alternan arranque lento con
# acelerones (simulando la oleada de paquetes).
#
# MECÁNICA ESPECIAL:
#   - Tiene MÁS vida que un Script Kiddie (el enjambre es difícil de tumbar).
#   - Su velocidad oscila (ráfaga) usando un Timer interno.
#
# CÓMO SE VE: el MeshHumanoid puede contener varios cuerpos pequeños (el
# spawner/controlador puede escalarlo o el shader lo decora).
extends "res://scripts/minigames/soc_td_3d/threats/base_threat_3d.gd"

## Velocidad máxima de la ráfaga (multiplicador).
@export var velocidad_rafaga_mult: float = 1.8

## Velocidad de crucero (multiplicador).
@export var velocidad_crucero_mult: float = 0.55

var _rafaga: bool = false
var _timer_rafaga: Timer


func _ready() -> void:
	super._ready()
	id_amenaza = "ddos_swarm"
	hp_max = 140.0
	hp = hp_max
	velocidad = 1.0
	puntos = 20

	# Oscilador de ráfaga: cada 0.9s alterna crucero/arranque.
	_timer_rafaga = Timer.new()
	_timer_rafaga.wait_time = 0.9
	_timer_rafaga.timeout.connect(_alternar_rafaga)
	add_child(_timer_rafaga)
	_timer_rafaga.start()


func _alternar_rafaga() -> void:
	_rafaga = not _rafaga
	# Guardamos el multiplicador de cuarentena para no pisarlo:
	# la ráfaga modula la velocidad BASE, no el estado lento.
	velocidad = 1.2 * (velocidad_rafaga_mult if _rafaga else velocidad_crucero_mult)


func destruir() -> void:
	if _timer_rafaga:
		_timer_rafaga.stop()
	super.destruir()
