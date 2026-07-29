# res://scripts/data/nivel_cyber_tools_data.gd
extends NivelArcadeData
class_name NivelCyberToolsData

@export_group("Configuración del Memorama")
@export var grid_filas: int = 3
@export var grid_columnas: int = 4
## Lista de herramientas/parejas para este nivel.
## Formato: [{"id": 0, "nombre": "Wireshark", "descripcion": "..."}]
@export var banco_herramientas: Array[Dictionary] = []
