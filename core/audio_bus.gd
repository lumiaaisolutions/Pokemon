extends Node
## Punto único para la música y los efectos (autoload AudioBus). Música de Pokémon
## Negro/Blanco y Negro 2/Blanco 2 (art/music/, solo local) con transición suave entre
## pistas y en bucle; fanfarrias cortas (curación, objeto, medalla, victoria, evolución)
## que bajan la música mientras suenan; efectos de sonido (art/sfx/). El volumen sale de
## Opciones (GameOptions).

const MUSIC_DIR := "res://art/music/"
const SFX_DIR := "res://art/sfx/"
const FADE := 1.4

var current := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _jingle: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _cache := {}
var _duck := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	_jingle = AudioStreamPlayer.new()
	add_child(_jingle)
	_jingle.finished.connect(func() -> void: _duck = 1.0)
	for i in 6:
		var sfx := AudioStreamPlayer.new()
		add_child(sfx)
		_sfx.append(sfx)


func _stream(dir: String, key: String) -> AudioStream:
	var id := dir + key
	if _cache.has(id):
		return _cache[id]
	var stream: AudioStream = null
	for extension in [".mp3", ".ogg", ".wav"]:
		if ResourceLoader.exists(dir + key + extension):
			stream = load(dir + key + extension) as AudioStream
			break
	_cache[id] = stream
	return stream


## ¿Existe la pista? (la música es local: puede no estar en otra copia del proyecto).
func has_music(key: String) -> bool:
	return _stream(MUSIC_DIR, key) != null


## Cambia la música (con transición). Si ya suena, no hace nada.
func play_music(key: String) -> void:
	if key == current or key == "":
		return
	var stream := _stream(MUSIC_DIR, key)
	if stream == null:
		return
	current = key
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var old := _players[_active]
	_active = 1 - _active
	var new := _players[_active]
	new.stream = stream
	new.volume_db = -40.0
	new.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(new, "volume_db", _target_db(), FADE)
	tween.tween_property(old, "volume_db", -60.0, FADE)
	tween.chain().tween_callback(old.stop)


func stop_music() -> void:
	current = ""
	for player in _players:
		var tween := create_tween()
		tween.tween_property(player, "volume_db", -60.0, FADE)
		tween.tween_callback(player.stop)


## Fanfarria corta: la música baja mientras suena.
func play_jingle(key: String) -> void:
	var stream := _stream(MUSIC_DIR, key)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	_jingle.stream = stream
	_jingle.volume_db = linear_to_db(maxf(GameOptions.music_volume, 0.001))
	_jingle.play()
	_duck = 0.15


## Efecto de sonido (si existe en art/sfx/).
func play_sfx(key: String, pitch: float = 1.0) -> void:
	var stream := _stream(SFX_DIR, key)
	if stream == null:
		return
	for player in _sfx:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = pitch
			player.volume_db = linear_to_db(maxf(GameOptions.effects_volume, 0.001))
			player.play()
			return


func _target_db() -> float:
	return linear_to_db(maxf(GameOptions.music_volume * 0.8 * _duck, 0.0005))


func _process(_delta: float) -> void:
	# Volumen de Opciones y bajada por fanfarria, sin cortar transiciones.
	var player := _players[_active]
	if player.playing and player.volume_db > -39.0:
		player.volume_db = move_toward(player.volume_db, _target_db(), 1.5)
