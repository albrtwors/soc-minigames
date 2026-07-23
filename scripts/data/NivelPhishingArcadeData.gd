# res://scripts/data/minigames/phishing/nivel_phishing_arcade_data.gd
extends NivelArcadeData
class_name NivelPhishingArcadeData

@export_group("Lote de Auditoría")
## Array de ítems (correos/facturas) que se presentarán durante la ronda
## Estructura de cada Dictionary:
## {
##   "emisor": "admin@paypaI.com",
##   "receptor": "compras@empresa.com",
##   "asunto": "Factura de Servidores Expirada",
##   "monto": "$1,200.00",
##   "cuerpo": "Estimado cliente, su cuenta será suspendida si no paga en 24h.",
##   "hash_impreso": "a1b2c3d4...",
##   "hash_real": "e5f6g7h8...", # Si no coincide con hash_impreso -> Es Fraude
##   "ssl_valido": false,
##   "es_fraude": true,
##   "motivo_fraude": "Typosquatting en el dominio (I mayúscula) y Hash alterado"
## }
@export var items_auditoria: Array[Dictionary] = []
