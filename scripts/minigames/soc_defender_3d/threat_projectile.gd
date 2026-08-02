# res://scripts/minigames/soc_defender_3d/threat_projectile.gd
extends Area3D
class_name ThreatProjectile

signal objetivo_alcanzado(amenaza: ThreatProjectile)

enum TipoAmenaza { EXPLOIT_CVE, DDOS, RANSOMWARE }

var id_amenaza: String = ""
var tipo_amenaza: TipoAmenaza = TipoAmenaza.EXPLOIT_CVE
var puerto_objetivo: int = 80
var rack_objetivo_index: int = 0
var velocidad: float = 1.5

var destino_pos: Vector3
var alcanzado: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var label_etiqueta: Label3D = $Label3D if has_node("Label3D") else null

func _process(delta: float) -> void:
	if alcanzado: return

	global_position = global_position.move_toward(destino_pos, velocidad * delta)

	if global_position.distance_to(destino_pos) < 0.1:
		alcanzado = true
		objetivo_alcanzado.emit(self)

func setup(data: Dictionary, pos_origen: Vector3, pos_destino: Vector3) -> void:
	global_position = pos_origen
	destino_pos = pos_destino

	id_amenaza = data.get("etiqueta", "CVE-2026-3142 [Port 80]")
	tipo_amenaza = data.get("tipo", TipoAmenaza.EXPLOIT_CVE) as TipoAmenaza
	puerto_objetivo = data.get("puerto", 80)
	rack_objetivo_index = data.get("rack_target", 0)
	velocidad = data.get("velocidad", 1.5)

	if label_etiqueta:
		label_etiqueta.text = id_amenaza

	_aplicar_estetica_tipo()

func _aplicar_estetica_tipo() -> void:
	if not mesh_instance: return

	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true

	match tipo_amenaza:
		TipoAmenaza.EXPLOIT_CVE:
			# Esfera de energía cibernética cyan/azul
			mat.albedo_color = Color(0.0, 0.8, 1.0)
			mat.emission = Color(0.0, 0.8, 1.0)
		TipoAmenaza.DDOS:
			# Ráfaga amarilla rápida
			mat.albedo_color = Color.YELLOW
			mat.emission = Color.YELLOW
			scale = Vector3(0.6, 0.6, 0.6)
		TipoAmenaza.RANSOMWARE:
			# Lanza roja/púrpura de infección
			mat.albedo_color = Color(0.8, 0.0, 0.2)
			mat.emission = Color(1.0, 0.0, 0.1)

	mesh_instance.material_override = mat

func destruir_con_animacion() -> void:
	alcanzado = true
	monitoring = false
	monitorable = false
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
	tween.finished.connect(queue_free)
