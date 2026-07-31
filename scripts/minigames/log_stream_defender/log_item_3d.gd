# res://scripts/minigames/log_stream_defender/log_item_3d.gd
extends Node3D

## Log individual que cae por un carril.
## Lo instancia y configura LogStreamDefender3D.

signal log_perdido(log_item: Node3D)

const Z_LIMITE_PERDIDO: float = 0.19

var texto: String = ""
var respuesta_correcta: int = 0
var velocidad_caida: float = 0.5
var esta_procesado: bool = false

@onready var panel_mesh: MeshInstance3D = $Panel
@onready var lbl_texto: Label3D = $Texto

var _material: StandardMaterial3D
var _tween: Tween

func _ready() -> void:
	var mat = panel_mesh.get_active_material(0) as StandardMaterial3D
	if mat:
		_material = mat.duplicate()
		panel_mesh.material_override = _material

func setup(texto_log: String, respuesta: int, velocidad: float) -> void:
	texto = texto_log
	respuesta_correcta = respuesta
	velocidad_caida = velocidad
	if lbl_texto:
		lbl_texto.text = texto_log

func _process(delta: float) -> void:
	if esta_procesado:
		return
	position.z += velocidad_caida * delta
	if position.z > Z_LIMITE_PERDIDO:
		esta_procesado = true
		log_perdido.emit(self)

func destruir_con_exito() -> void:
	_animar_resultado(Color(0.15, 0.9, 0.3, 1), true)

func destruir_con_error() -> void:
	_animar_resultado(Color(1.0, 0.2, 0.2, 1), false)

func _animar_resultado(color: Color, exito: bool) -> void:
	if esta_procesado:
		return
	esta_procesado = true
	set_process(false)

	if _tween:
		_tween.kill()

	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.set_parallel(true)
	if _material:
		_tween.tween_property(_material, "albedo_color", color, 0.12)
	_tween.tween_property(self, "position:y", position.y + 0.012, 0.12)
	if exito:
		_tween.tween_property(self, "scale", Vector3(1.5, 1.5, 1.5), 0.1)
	else:
		_tween.chain().tween_property(self, "position:x", position.x + 0.01, 0.05)
		_tween.chain().tween_property(self, "position:x", position.x - 0.01, 0.1)
		_tween.chain().tween_property(self, "position:x", position.x, 0.05)
	_tween.chain().tween_property(self, "scale", Vector3.ZERO, 0.3)
	_tween.chain().tween_callback(queue_free)
