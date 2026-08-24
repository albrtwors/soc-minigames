# SoundManager.gd (Autoload global)
# ============================================================
# Manager global para efectos de sonido (SFX).
# Crea AudioStreamPlayer bajo un nodo contenedor en /root.
# Permite reproducir múltiples sonidos concurrentes con control
# de volumen, pitch, y categorías.
#
# USO BÁSICO:
#   SoundManager.play("res://sounds/explosion.wav")
#   SoundManager.play(preload("res://sounds/laser.wav"))
#
# USO CON PARÁMETROS:
#   SoundManager.play("res://sounds/hit.wav", {"volume_db": -6, "pitch": 1.2})
#   SoundManager.play("res://sounds/coin.wav", {"category": "ui"})
#
# CATEGORÍAS (volumen independiente):
#   SoundManager.set_category_volume("sfx", 0.8)
#   SoundManager.set_category_volume("ui", 0.5)
#   SoundManager.set_category_volume("ambient", 0.3)
#
# DETENER:
#   SoundManager.stop_all()
#   SoundManager.stop_category("ui")
#
# AJUSTES DE VOLUMEN (persistencia automatica):
#   SoundManager.set_music_volume(0.8)  # lineal 0.0-1.0, aplica al bus "Music"
#   SoundManager.set_sfx_volume(0.5)    # lineal 0.0-1.0, aplica al bus "SFX"
#   SoundManager.get_music_volume()
#   SoundManager.get_sfx_volume()
#
# Los volúmenes se aplican sobre los buses "Music" y "SFX"
# (ver res://default_bus_layout.tres), afectando también a los
# sonidos ya en reproducción, y se guardan solos en
# user://settings.cfg (ajuste global, ajeno a las partidas).
# ============================================================
extends Node

## Categorías predefinidas con volumen base
var categories: Dictionary = {
	"sfx": 1.0,
	"ui": 1.0,
	"ambient": 1.0,
	"voice": 1.0,
}

var _players: Array[AudioStreamPlayer] = []
var _max_concurrent: int = 32

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"
const MIN_BUS_LINEAR := 0.0001  # evita -inf en linear_to_db; <=0.001 silencia el bus

signal audio_settings_changed(music_volume: float, sfx_volume: float)

## Volúmenes globales (lineal 0.0 - 1.0), persistidos automáticamente.
var music_volume: float = 1.0
var sfx_volume: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_audio_settings()

# --- API PÚBLICA ---

## Reproduce un efecto de sonido.
## [param stream] Ruta (String) o AudioStream directo.
## [param options] Diccionario opcional:
##   volume_db : float  (volumen extra en dB, default 0.0)
##   pitch     : float  (pitch scale, default 1.0)
##   category  : String (categoría para control de volumen, default "sfx")
##   from_position : float (posición de inicio en segundos, default 0.0)
## Retorna el AudioStreamPlayer creado (para control manual si se necesita).
func play(stream, options: Dictionary = {}) -> AudioStreamPlayer:
	var audio_stream: AudioStream = _resolve_stream(stream)
	if not audio_stream:
		push_warning("SoundManager: No se pudo cargar el stream: " + str(stream))
		return null

	var player := _get_free_player()
	if not player:
		push_warning("SoundManager: Límite de players alcanzado (" + str(_max_concurrent) + ")")
		return null

	var category: String = options.get("category", "sfx")
	var cat_volume: float = categories.get(category, 1.0)

	player.stream = audio_stream
	player.volume_db = options.get("volume_db", 0.0) + linear_to_db(cat_volume)
	player.pitch_scale = options.get("pitch", 1.0)
	# Meta necesario para que stop_category() pueda filtrar por categoría.
	player.set_meta("category", category)
	player.play(options.get("from_position", 0.0))

	return player

## Reproduce un sonido una sola vez con fade in rápido (para Transitions/UI).
func play_fade_in(stream, fade_time: float = 0.3, options: Dictionary = {}) -> AudioStreamPlayer:
	var player = play(stream, options)
	if not player:
		return null
	var target_db = player.volume_db
	player.volume_db = target_db - 40.0
	var tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, fade_time)
	return player

## Detiene todos los sonidos reproducándose.
func stop_all() -> void:
	for player in _players:
		if player.playing:
			player.stop()

## Detiene todos los sonidos de una categoría.
func stop_category(category: String) -> void:
	for player in _players:
		if player.playing and player.get_meta("category", "") == category:
			player.stop()

## Detiene un player específico retornado por play().
func stop_player(player: AudioStreamPlayer) -> void:
	if player and player.playing:
		player.stop()

## Pausa todos los sonidos.
func pause_all() -> void:
	for player in _players:
		if player.playing:
			player.stream_paused = true

## Reanuda todos los sonidos pausados.
func resume_all() -> void:
	for player in _players:
		if player.stream_paused:
			player.stream_paused = false

## Establece el volumen global de música (lineal, 0.0 a 1.0).
## Aplica al bus "Music" y guarda el ajuste automáticamente.
func set_music_volume(linear: float) -> void:
	music_volume = clamp(linear, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)
	_save_audio_settings()
	audio_settings_changed.emit(music_volume, sfx_volume)

## Obtiene el volumen global de música.
func get_music_volume() -> float:
	return music_volume

## Establece el volumen global de efectos (lineal, 0.0 a 1.0).
## Aplica al bus "SFX" y guarda el ajuste automáticamente.
func set_sfx_volume(linear: float) -> void:
	sfx_volume = clamp(linear, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)
	_save_audio_settings()
	audio_settings_changed.emit(music_volume, sfx_volume)

## Obtiene el volumen global de efectos.
func get_sfx_volume() -> float:
	return sfx_volume

## Establece el volumen global de SFX (lineal, 0.0 a 1.0).
func set_global_volume(linear: float) -> void:
	set_sfx_volume(linear)

## Establece el volumen de una categoría (lineal, 0.0 a 1.0).
func set_category_volume(category: String, linear: float) -> void:
	categories[category] = clamp(linear, 0.0, 1.0)

## Obtiene el volumen actual de una categoría.
func get_category_volume(category: String) -> float:
	return categories.get(category, 1.0)

## Retorna cuántos sonidos están sonando actualmente.
func get_playing_count() -> int:
	var count := 0
	for player in _players:
		if player.playing:
			count += 1
	return count

# --- AJUSTES DE VOLUMEN (user://settings.cfg) ---

## Guarda los ajustes de audio en disco (ajuste global, ajeno a las partidas).
func save_settings() -> void:
	_save_audio_settings()

func _save_audio_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, "music_volume", music_volume)
	config.set_value(SETTINGS_SECTION, "sfx_volume", sfx_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("SoundManager: No se pudo guardar %s (error %d)" % [SETTINGS_PATH, error])

func _load_audio_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_apply_all_bus_volumes()  # Primera ejecución: valores por defecto.
		return
	music_volume = clamp(float(config.get_value(SETTINGS_SECTION, "music_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clamp(float(config.get_value(SETTINGS_SECTION, "sfx_volume", 1.0)), 0.0, 1.0)
	_apply_all_bus_volumes()

func _apply_all_bus_volumes() -> void:
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)

func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("SoundManager: El bus de audio '%s' no existe." % bus_name)
		return
	AudioServer.set_bus_mute(bus_index, linear <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear, MIN_BUS_LINEAR)))

# --- INTERNOS ---

func _resolve_stream(stream) -> AudioStream:
	if stream is AudioStream:
		return stream
	if stream is String:
		return load(stream) as AudioStream
	return null

func _get_free_player() -> AudioStreamPlayer:
	# Reusar un player que ya terminó
	for player in _players:
		if not player.playing:
			return player
	# Crear uno nuevo si no se superó el límite
	if _players.size() < _max_concurrent:
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
		return player
	return null
