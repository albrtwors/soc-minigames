# res://scripts/minigames/soc_defender_3d/rack_server.gd
extends Node3D
class_name RackServer

signal puerto_estado_cambiado(puerto: int, abierto: bool)
signal rack_aislado(rack: RackServer)

enum EstadoRack { ESTABLE, BAJO_ATAQUE, INFECTADO }

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
var sla_uptime: float = 100.0

@onready var status_led: MeshInstance3D = $StatusLed if has_node("StatusLed") else null
@onready var area_clic: Area3D = $Area3D
@onready var panel_ui: Control = $RackUI/RackPanel if has_node("RackUI/RackPanel") else null

func _ready() -> void:
	actualizar_led_estado(EstadoRack.ESTABLE)
	_conectar_ui()
	_actualizar_botones_puertos()

## Muestra/oculta el panel de estado del rack (visible solo cuando la cámara lo enfoca).
func set_panel_visible(visible_ui: bool) -> void:
	if panel_ui:
		panel_ui.visible = visible_ui

func _conectar_ui() -> void:
	if not panel_ui:
		return
	var btn_http: Button = panel_ui.get_node_or_null("MarginContainer/VBoxContainer/PortHttp") as Button
	var btn_ssh: Button = panel_ui.get_node_or_null("MarginContainer/VBoxContainer/PortSsh") as Button
	var btn_https: Button = panel_ui.get_node_or_null("MarginContainer/VBoxContainer/PortHttps") as Button
	var btn_aislar: Button = panel_ui.get_node_or_null("MarginContainer/VBoxContainer/BtnIsolate") as Button
	if btn_http:
		btn_http.pressed.connect(func(): alternar_puerto(80))
	if btn_ssh:
		btn_ssh.pressed.connect(func(): alternar_puerto(22))
	if btn_https:
		btn_https.pressed.connect(func(): alternar_puerto(443))
	if btn_aislar:
		btn_aislar.pressed.connect(aislar_vlan)

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

	status_led.material_override = mat
	_actualizar_botones_puertos()

func alternar_puerto(puerto: int) -> bool:
	if puertos_estado.has(puerto):
		puertos_estado[puerto] = not puertos_estado[puerto]
		puerto_estado_cambiado.emit(puerto, puertos_estado[puerto])
		_actualizar_botones_puertos()
		return puertos_estado[puerto]
	return false

func aislar_vlan() -> void:
	esta_aislado = true
	actualizar_led_estado(EstadoRack.INFECTADO)
	rack_aislado.emit(self)

func _actualizar_botones_puertos() -> void:
	if not panel_ui:
		return
	var vbox: VBoxContainer = panel_ui.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if not vbox:
		return
	var btn_http: Button = vbox.get_node_or_null("PortHttp") as Button
	var btn_ssh: Button = vbox.get_node_or_null("PortSsh") as Button
	var btn_https: Button = vbox.get_node_or_null("PortHttps") as Button
	if btn_http:
		btn_http.text = "80/HTTP [%s]" % ("Abierto" if puertos_estado.get(80) else "Cerrado")
	if btn_ssh:
		btn_ssh.text = "22/SSH [%s]" % ("Abierto" if puertos_estado.get(22) else "Cerrado")
	if btn_https:
		btn_https.text = "443/HTTPS [%s]" % ("Abierto" if puertos_estado.get(443) else "Cerrado")
