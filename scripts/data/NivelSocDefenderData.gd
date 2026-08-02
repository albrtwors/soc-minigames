extends NivelArcadeData
class_name NivelSOCDefenderData

@export_group("Configuración General SOC")
## Velocidad base a la que viajan los proyectiles hacia los racks
@export var velocidad_amenazas_base: float = 1.5

## Intervalo en segundos entre la aparición de cada amenaza
@export var tiempo_entre_amenazas: float = 2.5

@export_subgroup("Banco de Amenazas / Oleadas")
## Arreglo de diccionarios con los ataques del nivel.
## Estructura esperada por cada elemento:
## {
##   "etiqueta": String (Ej: "CVE-2026-3142 [Port 80]"),
##   "tipo": int (0: EXPLOIT_CVE, 1: DDOS, 2: RANSOMWARE),
##   "rack_target": int (Índice del Rack 0 a 3),
##   "puerto": int (80, 443, 22, 3389, etc.),
##   "velocidad": float (Multiplicador o velocidad específica)
## }
@export var lista_amenazas: Array[Dictionary] = [
	{
		"etiqueta": "CVE-2026-3142 [Port 80]",
		"tipo": 0,
		"rack_target": 0,
		"puerto": 80,
		"velocidad": 1.2
	},
	{
		"etiqueta": "SYN FLOOD [Port 443]",
		"tipo": 1,
		"rack_target": 1,
		"puerto": 443,
		"velocidad": 2.0
	},
	{
		"etiqueta": "WORM_RANSOMWARE",
		"tipo": 2,
		"rack_target": 2,
		"puerto": 22,
		"velocidad": 1.0
	},
	{
		"etiqueta": "RDP EXPLOIT [Port 3389]",
		"tipo": 0,
		"rack_target": 3,
		"puerto": 3389,
		"velocidad": 1.5
	}
]
