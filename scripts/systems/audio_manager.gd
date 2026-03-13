# scripts/systems/audio_manager.gd
extends Node

## 音效管理器 — 统一管理 SFX 播放
## 作为 Autoload 单例全局可用

const POOL_SIZE: int = 8

var _sounds: Dictionary = {}  # sound_id -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0

var _bgm_player: AudioStreamPlayer
var _bgm_tracks: Dictionary = {}
var _current_bgm: String = ""

func _ready() -> void:
	_create_pool()
	_register_sounds()
	_create_bgm_player()
	_register_bgm()

func _create_pool() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)

func _register_sounds() -> void:
	var sfx_dir := "res://assets/sfx/"
	var sound_map: Dictionary = {
		"shoot": "shoot.wav",
		"hit": "hit.wav",
		"enemy_die": "enemy_die.wav",
		"coin_pickup": "coin_pickup.wav",
		"player_hit": "player_hit.wav",
		"wave_start": "wave_start.wav",
		"wave_complete": "wave_complete.wav",
		"shop_buy": "shop_buy.wav",
		"boss_appear": "boss_appear.wav",
		"tower_place": "tower_place.wav",
		"tower_remove": "tower_remove.wav",
	}
	for id: String in sound_map:
		var path: String = sfx_dir + sound_map[id]
		if ResourceLoader.exists(path):
			_sounds[id] = load(path)

func _create_bgm_player() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -6.0
	add_child(_bgm_player)

func _register_bgm() -> void:
	var bgm_dir := "res://assets/bgm/"
	var bgm_map: Dictionary = {
		"menu": "menu.ogg",
		"placement": "placement.ogg",
		"battle": "battle.ogg",
		"result": "result.ogg",
	}
	for id: String in bgm_map:
		var path: String = bgm_dir + bgm_map[id]
		if ResourceLoader.exists(path):
			_bgm_tracks[id] = load(path)

func play_bgm(track_id: String) -> void:
	if track_id == _current_bgm and _bgm_player.playing:
		return
	if not _bgm_tracks.has(track_id):
		return
	_bgm_player.stream = _bgm_tracks[track_id]
	_bgm_player.volume_db = -6.0
	_bgm_player.play()
	_current_bgm = track_id

func stop_bgm() -> void:
	_bgm_player.stop()
	_current_bgm = ""

func fade_bgm(duration: float = 0.5) -> void:
	if not _bgm_player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_bgm_player, "volume_db", -40.0, duration)
	tween.tween_callback(stop_bgm)

func play(sound_id: String, volume_db: float = 0.0) -> void:
	if not _sounds.has(sound_id):
		return
	var player: AudioStreamPlayer = _pool[_pool_index]
	player.stream = _sounds[sound_id]
	player.volume_db = volume_db
	player.play()
	_pool_index = (_pool_index + 1) % POOL_SIZE
