# res://scripts/data/NivelSocTdData.gd
# ============================================================
# DATOS DE NIVEL PARA "SOC Defender: Cyber Lane Defense"
# ============================================================
# Cada archivo .tres de nivel (res://scripts/data/soc_td_levels/)
# hidrata un objeto de esta clase. El controlador principal
# (soc_td_main.gd) lee estos valores para configurar la partida.
#
# PARA AÑADIR UN NIVEL:
#   1. Crea un .tres nuevo en scripts/data/soc_td_levels/
#   2. Configura los exports de abajo (los valores por defecto sirven).
#   3. Regístralo en minigame_frame_updated.gd -> level_data_resources.
extends NivelArcadeData
class_name NivelSocTdData

@export_group("Presupuesto y Partida")
## Presupuesto de TI con el que arranca la partida (en $).
@export var presupuesto_inicial: int = 150

## Tiempo que debe sobrevivir el operador (en segundos). Heredado de
## NivelArcadeData.tiempo_limite pero lo exponemos aquí con su propio valor
## por defecto para que cada nivel lo sobreescriba cómodamente.
@export var duracion_partida: float = 90.0

## Coste (en $) de cada tipo de defensa. Las claves son los ids que usa el
## HUD y soc_td_main.gd. Si una clave falta, se usa el valor por defecto del
## diccionario que hay dentro de soc_td_main.gd (TABLA_COSTOS).
@export var costos_defensas: Dictionary = {}

## Valor en $ de cada token que genera el Servidor PDU.
@export var valor_token_uptime: int = 25

## Descuento de "disponibilidad" (en $) si dejas caducar un token sin recogerlo.
@export var penalizacion_token_caducado: int = 5

@export_group("Spawn de Amenazas")
## Segundos entre cada aparición de amenaza.
@export var tiempo_entre_amenazas: float = 2.0

## Multiplicador de velocidad global de las amenazas.
@export var velocidad_base: float = 1.0

## Pool de amenazas: en cada tick el spawner elige una al azar (ponderada).
## Estructura de cada elemento:
## {
##   "id": String        (clave de amenaza: "script_kdd", "ddos_swarm",
##                        "ransomware", "apt"),
##   "peso": float       (probabilidad relativa de aparición),
## }
@export var pool_amenazas: Array[Dictionary] = [
	{"id": "script_kdd", "peso": 5.0},
	{"id": "script_kdd", "peso": 5.0},
	{"id": "ddos_swarm", "peso": 2.5},
	{"id": "ransomware", "peso": 1.5},
	{"id": "apt", "peso": 1.0}
]

@export_group("Puntuación")
## Puntos por eliminar una amenaza (multiplicado por su valor en puntos).
@export var puntos_por_amenaza: int = 10

## Puntos de penalización por cada amenaza que cruza el Firewall de Respaldo.
@export var penalizacion_brecha: int = 100

## Bonus por presupuesto sin gastar al terminar la partida ($ -> puntos).
@export var puntos_por_dolar_restante: int = 1
