extends NivelArcadeData
class_name NivelSOCDefenderData

@export_group("Configuración General SOC")
## Velocidad base a la que viajan los proyectiles hacia los racks
@export var velocidad_amenazas_base: float = 1.5

## Intervalo en segundos entre la aparición de cada amenaza
@export var tiempo_entre_amenazas: float = 2.5

@export_subgroup("Pool de Amenazas (Aleatorias)")
## Conjunto de ataques que PUEDEN ocurrir durante la partida.
## En cada aparición el minijuego elige UNO al azar de este pool y le asigna
## un rack (carril) también aleatorio. La partida dura tiempo_limite (heredado
## de NivelArcadeData): no hay un número fijo de ataques ni rutas predefinidas.
## Estructura esperada por cada elemento:
## {
##   "etiqueta": String (Ej: "CVE-2026-3142 [Port 80]"),
##   "tipo": int (0: EXPLOIT_CVE, 1: DDOS, 2: RANSOMWARE),
##   "puerto": int (80, 443, 22, 3389, etc.),
##   "velocidad": float (Multiplicador de velocidad_amenazas_base)
## }
@export var pool_amenazas: Array[Dictionary] = [
	{
		"etiqueta": "CVE-2026-3142 [Port 80]",
		"tipo": 0,
		"puerto": 80,
		"velocidad": 1.2
	},
	{
		"etiqueta": "SYN FLOOD [Port 443]",
		"tipo": 1,
		"puerto": 443,
		"velocidad": 2.0
	},
	{
		"etiqueta": "WORM_RANSOMWARE",
		"tipo": 2,
		"puerto": 22,
		"velocidad": 1.0
	},
	{
		"etiqueta": "RDP EXPLOIT [Port 3389]",
		"tipo": 0,
		"puerto": 3389,
		"velocidad": 1.5
	},
	{
		"etiqueta": "HTTP FLOOD [Port 80]",
		"tipo": 1,
		"puerto": 80,
		"velocidad": 1.7
	},
	{
		"etiqueta": "CVE-2025-10086 [Port 22]",
		"tipo": 0,
		"puerto": 22,
		"velocidad": 1.3
	}
]
