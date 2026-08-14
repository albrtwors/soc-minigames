# res://scripts/minigames/soc_defender_3d/rack_server.gd
extends Node3D
class_name RackServer

signal puerto_estado_cambiado(puerto: int, abierto: bool)
signal rack_aislado(rack: RackServer)
signal rack_rollback_aplicado(rack: RackServer)
signal rack_reconectado(rack: RackServer)
signal scrubbing_activado(rack: RackServer)
signal parche_aplicado(rack: RackServer, progreso: int)

enum EstadoRack { ESTABLE, BAJO_ATAQUE, INFECTADO, AISLADO, RECUPERANDO }

const PATCH_INCREMENTO: float = 25.0

@export var rack_index: int = 0
var estado_actual: EstadoRack = EstadoRack.ESTABLE

# Estado de Puertos (True = Abierto/Activo, False = Cerrado/Bloqueado)
var puertos_estado: Dictionary = {
	80: true,   # HTTP
	22: true,   # SSH
	443: true,  # HTTPS
	3389: true  # RDP
}

var esta_aislado: bool = false
var esta_infectado: bool = false

const PUERTOS_NOMBRE := {80: "HTTP", 22: "SSH", 443: "HTTPS", 3389: "RDP"}
const PUERTOS_BOTON := {80: "PortHttp", 22: "PortSsh", 443: "PortHttps", 3389: "PortRdp"}

@onready var status_led: MeshInstance3D = $StatusLed if has_node("StatusLed") else null
@onready var area_clic: Area3D = $Area3D
@onready var panel_ui: Control = $RackUI/RackPanel if has_node("RackUI/RackPanel") else null

func _ready() -> void:
	actualizar_led_estado(EstadoRack.ESTABLE)
	_conectar_ui()
	_actualizar_panel_estado()

## Muestra/oculta el panel de estado del rack (visible solo cuando la cámara lo enfoca).
func set_panel_visible(visible_ui: bool) -> void:
	if panel_ui:
		panel_ui.visible = visible_ui

func _btn(nombre: String) -> Button:
	if not panel_ui:
		return null
	return panel_ui.get_node_or_null("MarginContainer/VBoxContainer/" + nombre) as Button

func _barra_patch() -> ProgressBar:
	if not panel_ui:
		return null
	return panel_ui.get_node_or_null("MarginContainer/VBoxContainer/PatchProgressBar") as ProgressBar

func _conectar_ui() -> void:
	for puerto in PUERTOS_BOTON:
		var b := _btn(PUERTOS_BOTON[puerto])
		if b:
			b.pressed.connect(func(): alternar_puerto(puerto))
	var scrub := _btn("BtnScrub")
	if scrub:
		scrub.pressed.connect(scrubbing)
	var patch := _btn("BtnPatch")
	if patch:
		patch.pressed.connect(aplicar_parche)
	var iso := _btn("BtnIsolate")
	if iso:
		iso.pressed.connect(aislar_vlan)
	var roll := _btn("BtnRollback")
	if roll:
		roll.pressed.connect(restaurar_backup)
	var recon := _btn("BtnReconnect")
	if recon:
		recon.pressed.connect(reconectar)

## Un rack operativo puede administrar puertos y parches. Infectado o aislado: bloqueado.
func puede_operar() -> bool:
	return not esta_aislado and not esta_infectado

func actualizar_led_estado(nuevo_estado: EstadoRack) -> void:
	estado_actual = nuevo_estado
	if not status_led:
		return

	var mat = StandardMaterial3D.new()
	match nuevo_estado:
		EstadoRack.ESTABLE:
			mat.albedo_color = Color.GREEN
			mat.emission_enabled = true
			mat.emission = Color.GREEN
		EstadoRack.BAJO_ATAQUE:
			mat.albedo_color = Color.YELLOW
			mat.emission_enabled = true
			mat.emission = Color.YELLOW
		EstadoRack.INFECTADO:
			mat.albedo_color = Color.RED
			mat.emission_enabled = true
			mat.emission = Color.RED
		EstadoRack.AISLADO:
			mat.albedo_color = Color(1.0, 0.6, 0.0)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.6, 0.0)
		EstadoRack.RECUPERANDO:
			mat.albedo_color = Color(0.2, 0.6, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.6, 1.0)

	status_led.material_override = mat
	_actualizar_botones_puertos()

func alternar_puerto(puerto: int) -> bool:
	if not puede_operar():
		return false
	if puertos_estado.has(puerto):
		puertos_estado[puerto] = not puertos_estado[puerto]
		puerto_estado_cambiado.emit(puerto, puertos_estado[puerto])
		_actualizar_botones_puertos()
		return puertos_estado[puerto]
	return false

func scrubbing() -> void:
	if not puede_operar():
		return
	scrubbing_activado.emit(self)

func aplicar_parche() -> void:
	if not puede_operar():
		return
	var barra := _barra_patch()
	if not barra:
		return
	barra.value = clampf(barra.value + PATCH_INCREMENTO, 0.0, 100.0)
	parche_aplicado.emit(self, int(barra.value))

func marcar_infectado() -> void:
	esta_infectado = true
	actualizar_led_estado(EstadoRack.INFECTADO)
	_actualizar_panel_estado()

func aislar_vlan() -> void:
	if not esta_infectado or esta_aislado:
		return
	esta_aislado = true
	actualizar_led_estado(EstadoRack.AISLADO)
	rack_aislado.emit(self)
	_actualizar_panel_estado()

func restaurar_backup() -> void:
	if not esta_aislado or not esta_infectado:
		return
	esta_infectado = false
	actualizar_led_estado(EstadoRack.RECUPERANDO)
	rack_rollback_aplicado.emit(self)
	_actualizar_panel_estado()

func reconectar() -> void:
	if not esta_aislado or esta_infectado:
		return
	esta_aislado = false
	actualizar_led_estado(EstadoRack.ESTABLE)
	rack_reconectado.emit(self)
	_actualizar_panel_estado()

func reiniciar_partida() -> void:
	esta_aislado = false
	esta_infectado = false
	for puerto in puertos_estado:
		puertos_estado[puerto] = true
	var barra := _barra_patch()
	if barra:
		barra.value = 0.0
	actualizar_led_estado(EstadoRack.ESTABLE)
	_actualizar_botones_puertos()
	_actualizar_panel_estado()

func _actualizar_botones_puertos() -> void:
	if not panel_ui:
		return
	var operativo := puede_operar()
	for puerto in PUERTOS_BOTON:
		var b := _btn(PUERTOS_BOTON[puerto])
		if b:
			b.text = "%d/%s [%s]" % [puerto, PUERTOS_NOMBRE[puerto],
				"Abierto" if puertos_estado.get(puerto) else "Cerrado"]
			b.disabled = not operativo

func _actualizar_panel_estado() -> void:
	if not panel_ui:
		return
	var operativo := puede_operar()
	var mostrar_aislar: bool = esta_infectado and not esta_aislado
	var mostrar_rollback: bool = esta_aislado and esta_infectado
	var mostrar_reconectar: bool = esta_aislado and not esta_infectado

	for nombre in PUERTOS_BOTON.values():
		var b := _btn(nombre)
		if b:
			b.visible = operativo
	var scrub := _btn("BtnScrub")
	if scrub:
		scrub.visible = operativo
	var patch := _btn("BtnPatch")
	if patch:
		patch.visible = operativo
	var barra := _barra_patch()
	if barra:
		barra.visible = operativo

	var iso := _btn("BtnIsolate")
	if iso:
		iso.visible = mostrar_aislar
	var roll := _btn("BtnRollback")
	if roll:
		roll.visible = mostrar_rollback
	var recon := _btn("BtnReconnect")
	if recon:
		recon.visible = mostrar_reconectar

	_actualizar_botones_puertos()
