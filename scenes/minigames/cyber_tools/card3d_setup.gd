extends Node3D
class_name Card3D

signal carta_levantada(carta: Card3D)
signal carta_bajada(carta: Card3D)

var id_par: int = -1
var es_tarjeta_concepto: bool = false
var esta_levantada: bool = false
var esta_emparejada: bool = false

@onready var area_3d: Area3D = $Area3D
@onready var lbl_tool: Label3D = $ToolLabel
@onready var lbl_description: Label3D = $Description

var rotacion_inicial: Vector3
var posicion_base: Vector3
var inicializado: bool = false
var tween_carta: Tween

func _ready() -> void:
	if area_3d:
		area_3d.input_event.connect(_on_input_event)

func setup(id: int, es_concepto: bool, contenido_texto: String) -> void:
	id_par = id
	es_tarjeta_concepto = es_concepto

	if not is_node_ready():
		await ready

	_fijar_transformacion_base()

	if es_tarjeta_concepto:
		if lbl_tool: lbl_tool.hide()
		if lbl_description:
			lbl_description.text = contenido_texto
			lbl_description.show()
	else:
		if lbl_description: lbl_description.hide()
		if lbl_tool:
			lbl_tool.text = contenido_texto
			lbl_tool.show()

func _fijar_transformacion_base() -> void:
	rotacion_inicial = rotation_degrees
	posicion_base = position
	inicializado = true

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if not esta_levantada and not esta_emparejada:
				levantar_carta()
		MOUSE_BUTTON_RIGHT:
			if esta_levantada and not esta_emparejada:
				bajar_carta()

func levantar_carta() -> void:
	if esta_levantada: return
	esta_levantada = true

	if tween_carta and tween_carta.is_running():
		tween_carta.kill()

	var target_rot = rotacion_inicial + Vector3(180.0, 0.0, 0.0)
	var target_pos = posicion_base + Vector3(0, 0.02, 0)

	tween_carta = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_carta.set_parallel(true)
	tween_carta.tween_property(self, "position", target_pos, 0.35)
	tween_carta.tween_property(self, "rotation_degrees", target_rot, 0.35)

	carta_levantada.emit(self)

func bajar_carta() -> void:
	if not esta_levantada: return
	esta_levantada = false

	if tween_carta and tween_carta.is_running():
		tween_carta.kill()

	tween_carta = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_carta.set_parallel(true)
	tween_carta.tween_property(self, "position", posicion_base, 0.3)
	tween_carta.tween_property(self, "rotation_degrees", rotacion_inicial, 0.3)

	carta_bajada.emit(self)

func animar_resultado(es_correcto: bool) -> void:
	if tween_carta and tween_carta.is_running():
		tween_carta.kill()

	if es_correcto:
		esta_emparejada = true
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	else:
		bajar_carta()
