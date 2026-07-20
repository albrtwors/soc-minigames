# terminal_text.gd
extends RichTextLabel

var commands: Array[String] = [
	"soc@admin:~$ nmap -sV -O 192.168.1.1",
	"Starting Nmap 7.92 ( https://nmap.org )",
	"Nmap scan report for gateway (192.168.1.1)",
	"Host is up (0.002s latency).",
	"PORT     STATE  SERVICE",
	"22/tcp   open   ssh",
	"80/tcp   open   http",
	"443/tcp  open   https",
	"soc@admin:~$ tail -f /var/log/auth.log",
	"Jul 16 16:23:44 soc-node sshd[4012]: pam_unix(sshd:auth): authentication failure;",
	"Jul 16 16:23:46 soc-node sshd[4012]: Failed password for invalid user root",
	"soc@admin:~$ systemctl status soc-firewall.service",
	"● soc-firewall.service - SOC Active Defense Firewall",
	"   Loaded: loaded (/etc/systemd/system/soc-firewall.service; enabled)",
	"   Active: active (running) since Thu 2026-07-16;",
	"   Main PID: 1042 (soc-fw)",
	"   Tasks: 4 (limit: 4915)",
	"soc@admin:~$ iptables -A INPUT -s 203.0.113.50 -j DROP",
	"WARNING: Bypassing firewall rule validation...",
	"Database integrity status: SECURE",
	"Decrypting packet payload... OK",
	"Packet signature verified: SHA-256 matches.",
]

var timer: Timer

func _ready() -> void:
	# Configurar el estilo visual estilo fósforo de terminal antigua
	bbcode_enabled = true
	text = "[color=#00f3ff]SOC OS v4.6.2 Init...[/color]\n"
	
	# Creamos un temporizador dinámico para simular la velocidad de escritura
	timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.4
	timer.timeout.connect(_add_random_line)
	timer.start()

func _add_random_line() -> void:
	# Tomamos una línea al azar de nuestra lista de comandos
	var random_line = commands[randi() % commands.size()]
	
	# Agregamos la línea al RichTextLabel
	append_text("[color=#00f3ff]" + random_line + "[/color]\n")
	
	# Si el texto es demasiado largo, borramos las primeras líneas para que no consuma memoria
	if get_line_count() > 30:
		clear()
		append_text("[color=#00f3ff]-- System Buffer Cleared --[/color]\n")
		
	# Ajustar el scroll automático hacia abajo para que siempre se vea la última línea
	scroll_to_line(get_line_count() - 1)
	
	# Variar ligeramente la velocidad de la siguiente línea para que se sienta humano/proceso real
	timer.wait_time = randf_range(0.1, 0.8)
