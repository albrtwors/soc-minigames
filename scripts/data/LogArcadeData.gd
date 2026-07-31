extends NivelArcadeData
class_name NivelLogArcadeData

# Usamos una subclase/estructura interna o un sub-recurso para cada log del nivel
@export_group("Configuración Log Defender")
@export var cantidad_carriles: int = 3
@export var velocidad_caida: float = 0.5

@export_subgroup("Banco de Logs del Nivel")
# Lista de diccionarios o elementos configurables desde el inspector
# Estructura de cada dicc: {"texto": String, "respuesta": int (0: IGNORAR, 1: BLOQUEAR, 2: AISLAR)}
@export var lista_logs: Array[Dictionary] = [
	{"texto": "GET /index.html 200 OK", "respuesta": 0},
	{"texto": "POST /login 401 [50 req/s]", "respuesta": 1},
	{"texto": "HOST_03 -> 185.220.x:4444 [RAT]", "respuesta": 2}
]
