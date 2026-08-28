# MusicManager.gd (Autoload global)
# ============================================================
# Manager global para música con transiciones fade.
# Un solo AudioStreamPlayer con dos capas (layer A y B) permite
# crossfade entre pistas sin cortes.
#
# USO BÁSICO:
#   MusicManager.play("res://music/main_theme.ogg")
#   MusicManager.play(preload("res://music/battle.ogg"))
#
# CAMBIAR MÚSICA (fade out → fade in):
#   MusicManager.fade_to("res://music/boss.ogg", 1.5)
#
# PARAR MÚSICA:
#   MusicManager.stop()           # corte seco
#   MusicManager.fade_out(2.0)    # fade progresivo
#
# PAUSA / REANUDAR:
#   MusicManager.pause()
#   MusicManager.resume()
#
# VOLUMEN:
#   MusicManager.set_volume(0.7)   # lineal 0.0-1.0
#   MusicManager.get_volume()
#
# INFORMACIÓN:
#   MusicManager.is_playing()
#   MusicManager.get_current_track()
#   MusicManager.get_position()
#   MusicManager.seek(12.5)
#
# PLAYLIST ALEATORIA:
#   MusicManager.play_playlist([ruta1, ruta2, ...])  # orden aleatorio continuo
#   Señal track_changed(track_path) al iniciar cada pista.
#
# AUTOPLAY:
#   MusicManager.set_autoplay("res://music/menu.ogg")
# ============================================================
extends Node

## Volumen actual (lineal, 0.0 a 1.0)
var volume: float = 1.0

var _layer_a: AudioStreamPlayer
var _layer_b: AudioStreamPlayer
var _active_layer: AudioStreamPlayer  # el que está sonando
var _idle_layer: AudioStreamPlayer    # el que está libre para crossfade
var _current_track: String = ""
var _autoplay_track: String = ""
var _tween: Tween
var _fade_time: float = 1.0
## Pistas pendientes del modo playlist (vacío = reproduccion normal).
var _playlist: Array[String] = []
## Segundos de fade-out antes de que termine cada pista en modo playlist.
const TRACK_END_FADE := 3.0
var _end_fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer_a = AudioStreamPlayer.new()
	_layer_a.bus = "Music"
	_layer_a.name = "MusicLayerA"
	add_child(_layer_a)

	_layer_b = AudioStreamPlayer.new()
	_layer_b.bus = "Music"
	_layer_b.name = "MusicLayerB"
	add_child(_layer_b)

	_active_layer = _layer_a
	_idle_layer = _layer_b

	_layer_a.finished.connect(_on_track_finished.bind(_layer_a))
	_layer_b.finished.connect(_on_track_finished.bind(_layer_b))

func _process(_delta: float) -> void:
	# Sync del volumen objetivo en la capa activa, salvo que haya un
	# fade en curso (fade-in, crossfade o fade-out de fin de pista).
	if _active_layer.playing and not _is_fading():
		_active_layer.volume_db = linear_to_db(volume)
	_update_playlist_end_fade()

## true si hay algún fade de volumen en progreso.
func _is_fading() -> bool:
	if _end_fade_tween and _end_fade_tween.is_valid():
		return true
	return _tween != null and _tween.is_valid()

# --- API PÚBLICA ---

## Reproduce una pista. Si ya hay música, hace crossfade.
## [param path] Ruta (String) o AudioStream directo.
## [param crossfade_time] Duración del crossfade en segundos. 0.0 = corte seco.
func play(stream, crossfade_time: float = 1.0) -> void:
	var audio_stream: AudioStream = _resolve_stream(stream)
	if not audio_stream:
		push_warning("MusicManager: Stream no válido: " + str(stream))
		return

	# Si es la misma pista, no hacer nada
	var new_path = stream if stream is String else ""
	if new_path != "" and new_path == _current_track and _active_layer.playing:
		return

	_cancel_tween()
	_kill_end_fade()
	_fade_time = crossfade_time

	if _active_layer.playing and crossfade_time > 0.0:
		_crossfade(audio_stream, crossfade_time)
	else:
		_active_layer.stream = audio_stream
		_apply_playlist_no_loop(audio_stream)
		# Arranca en silencio y hace fade-in para no ser brusco
		# (típico al encadenar pistas tras un finished).
		_active_layer.volume_db = -60.0
		_active_layer.play()
		_idle_layer.stop()
		_fade_in_active(crossfade_time)

	_current_track = new_path
	if new_path != "":
		track_changed.emit(new_path)

## Reproduce una lista de pistas en orden aleatorio (estilo playlist).
## Al terminar cada pista avanza a otra aleatoria sin repetir la actual,
## con crossfade. Emite track_changed(track_path) al iniciar cada una.
func play_playlist(tracks: Array[String], crossfade_time: float = 1.5) -> void:
	if tracks.is_empty():
		push_warning("MusicManager: Playlist vacia.")
		return
	_playlist = tracks.duplicate()
	_play_next_track(crossfade_time)

## Cambia a otra pista con crossfade suave.
## [param path] Ruta o AudioStream de la nueva pista.
## [param duration] Duración del crossfade en segundos.
func fade_to(stream, duration: float = 1.5) -> void:
	play(stream, duration)

## Fade out de la música actual y la detiene.
## [param duration] Duración del fade en segundos.
func fade_out(duration: float = 1.0) -> void:
	if not _active_layer.playing:
		return
	_cancel_tween()
	_tween = create_tween()
	_tween.tween_property(_active_layer, "volume_db", -60.0, duration)
	_tween.tween_callback(func():
		_active_layer.stop()
		_current_track = ""
	)

## Detiene la música de golpe (sin fade).
func stop() -> void:
	_cancel_tween()
	_kill_end_fade()
	_active_layer.stop()
	_idle_layer.stop()
	_current_track = ""
	_playlist.clear()

## Pausa la música actual.
func pause() -> void:
	_active_layer.stream_paused = true

## Reanuda la música pausada.
func resume() -> void:
	_active_layer.stream_paused = false

## Salta a una posición específica en segundos.
func seek(position: float) -> void:
	if _active_layer.playing:
		_active_layer.seek(position)

## Establece el volumen de música (lineal, 0.0 a 1.0).
func set_volume(linear: float) -> void:
	volume = clamp(linear, 0.0, 1.0)
	if _active_layer.playing:
		_active_layer.volume_db = linear_to_db(volume)

## Obtiene el volumen actual.
func get_volume() -> float:
	return volume

## Retorna true si la música está sonando.
func is_playing() -> bool:
	return _active_layer.playing

## Retorna la ruta de la pista actual.
func get_current_track() -> String:
	return _current_track

## Retorna la posición actual en segundos.
func get_position() -> float:
	if _active_layer.playing:
		return _active_layer.get_playback_position()
	return 0.0

## Retorna la duración total de la pista actual.
func get_length() -> float:
	if _active_layer.stream:
		return _active_layer.stream.get_length()
	return 0.0

## Establece una pista para autoplay cuando MusicManager esté listo.
func set_autoplay(path: String) -> void:
	_autoplay_track = path

## Detiene y limpia el autoplay.
func clear_autoplay() -> void:
	_autoplay_track = ""

## Retorna el nombre del layer activo ("A" o "B").
func get_active_layer_name() -> String:
	return "A" if _active_layer == _layer_a else "B"

# --- SEÑALES (para conectar desde minijuegos) ---

## Emitida cuando termina una pista (solo si no tiene loop).
signal track_finished(track_path: String)

## Emitida cada vez que arranca una pista (play, fade_to o playlist).
signal track_changed(track_path: String)

# --- INTERNOS ---

## Elige una pista aleatoria de la playlist evitando repetir la actual
## y la reproduce. Si la playlist esta vacia no hace nada.
func _play_next_track(crossfade_time: float = 1.5) -> void:
	if _playlist.is_empty():
		return
	var candidates: Array = _playlist.filter(func(p): return p != _current_track)
	var pool: Array = candidates if not candidates.is_empty() else _playlist
	play(pool.pick_random(), crossfade_time)

## En modo playlist las pistas nunca hacen loop interno: al acabar
## el stream dispara finished y la playlist avanza a la siguiente.
func _apply_playlist_no_loop(stream: AudioStream) -> void:
	if not _playlist.is_empty() and "loop" in stream:
		stream.loop = false

## Fade-in progresivo del layer activo hacia el volumen objetivo.
## Con duration <= 0 arranca directo (comportamiento instantáneo).
func _fade_in_active(duration: float) -> void:
	if duration <= 0.0:
		_active_layer.volume_db = linear_to_db(volume)
		return
	_tween = create_tween()
	_tween.tween_property(_active_layer, "volume_db", linear_to_db(volume), duration)

func _kill_end_fade() -> void:
	if _end_fade_tween and _end_fade_tween.is_valid():
		_end_fade_tween.kill()
	_end_fade_tween = null

## En modo playlist, cuando a la pista actual le quedan menos de
## TRACK_END_FADE segundos inicia un fade-out suave hacia el silencio,
## para que el paso a la siguiente canción no sea brusco.
func _update_playlist_end_fade() -> void:
	if _playlist.is_empty() or not _active_layer.playing:
		return
	if _active_layer.stream == null or _is_fading():
		return
	var restante := _active_layer.stream.get_length() - _active_layer.get_playback_position()
	if restante > 0.0 and restante <= TRACK_END_FADE:
		_end_fade_tween = create_tween()
		_end_fade_tween.tween_property(_active_layer, "volume_db", -60.0, maxf(restante, 0.1))

func _crossfade(new_stream: AudioStream, duration: float) -> void:
	# El idle layer empieza la nueva pista
	_idle_layer.stream = new_stream
	_apply_playlist_no_loop(new_stream)
	_idle_layer.volume_db = -60.0
	_idle_layer.play()

	# Tween: idle sube, active baja
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_idle_layer, "volume_db", linear_to_db(volume), duration).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_active_layer, "volume_db", -60.0, duration).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		_active_layer.stop()
		# Swapear capas
		var temp = _active_layer
		_active_layer = _idle_layer
		_idle_layer = temp
	)

func _on_track_finished(layer: AudioStreamPlayer) -> void:
	if layer != _active_layer:
		return
	if not _playlist.is_empty():
		# Modo playlist: encadenar la siguiente pista aleatoria.
		_play_next_track(_fade_time)
		return
	_current_track = ""
	track_finished.emit(_current_track)

func _cancel_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null

func _resolve_stream(stream) -> AudioStream:
	if stream is AudioStream:
		return stream
	if stream is String:
		return load(stream) as AudioStream
	return null
