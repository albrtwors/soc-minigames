# res://scripts/data/nivel_topologia_data.gd
extends NivelArcadeData
class_name NivelTopologiaData

enum FaseMinijuego { TOPOLOGIA = 0, BASTIONADO = 1, INTEGRADO = 2 }

@export_group("Configuración Infrastructure Rush")
## Fase del nivel: 0 = Topología pura, 1 = Bastionado puro, 2 = Integrado.
@export var fase: int = FaseMinijuego.INTEGRADO

@export_subgroup("Topología")
## Definición de dispositivos de la red. Estructura de cada elemento:
## {
##   "id": String (Ej: "router_edge"),
##   "nombre": String (Ej: "ROUTER EDGE"),
##   "tipo": String ("router" | "switch" | "firewall" | "servidor" | "bastion"),
##   "x": float, "z": float (posición sobre la mesa),
##   "modelo_3d": String opcional (ruta .tscn del modelo a instanciar;
##     si se omite o falla la carga, se usa la caja procedural por defecto),
##   "directivas": [ { "id": String, "etiqueta": String, "correcta": bool, "estado": bool } ]
## }
## "correcta" define el estado esperado (bastionado); "estado" es el estado inicial.
@export var dispositivos: Array[Dictionary] = []

## NOTA: "conexiones_requeridas" y "nodos_disponibles" se heredan de NivelArcadeData.
## Estructura de cada conexión: { "origen": String, "destino": String, "etiqueta": String }

@export_subgroup("Puntuación")
@export var puntos_cable_correcto: int = 200
@export var puntos_nodo_perfecto: int = 150
@export var puntos_bonus_por_segundo: int = 10
@export var penalizacion_segmentacion: int = 100
@export var penalizacion_test: int = 150

@export_subgroup("Auditoría")
## Número máximo de auditorías (LANZAR TEST) antes de perder. Al llegar a 0 -> derrota.
@export var intentos_test: int = 3
## Velocidad de los paquetes de test (unidades por segundo).
@export var velocidad_test: float = 2.0
