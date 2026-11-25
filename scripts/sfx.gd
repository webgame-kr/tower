class_name GSfx
extends Node
## 효과음: motion.json 규칙 (같은 소리 0.05초 안에 3번까지, 음높이 ±5%, 묶음별 크기).
## 파일은 res://audio/sfx/<이름>.ogg, 처음 쓸 때 불러온다.

const BUS := {"tw": 0.6, "rx": 0.8, "en": 0.5, "ui": 0.7, "ping": 0.7, "rd": 0.7, "bd": 0.8, "hq": 1.0, "wv": 1.0}
const MAX_OVERLAP := 3
const WINDOW := 0.05
const PITCH := 0.05
const VOICES := 14

var volume := 0.8      # 설정의 효과음 크기 (0~1)
var _players: Array = []
var _streams := {}
var _recent := {}


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(name: String, gain := 1.0) -> void:
	if volume <= 0.0 or name == "":
		return
	var now := Time.get_ticks_msec() / 1000.0
	var times: Array = (_recent.get(name, []) as Array).filter(func(t): return now - float(t) < WINDOW)
	if times.size() >= MAX_OVERLAP:
		return
	times.append(now)
	_recent[name] = times
	if not _streams.has(name):
		var path := "res://audio/sfx/%s.ogg" % name
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	var st = _streams[name]
	if st == null:
		return
	var pick: AudioStreamPlayer = null
	for p in _players:
		if not (p as AudioStreamPlayer).playing:
			pick = p
			break
	if pick == null:      # 다 차면 가장 오래 울린 것을 끊는다
		pick = _players[0]
		for p in _players:
			if (p as AudioStreamPlayer).get_playback_position() > pick.get_playback_position():
				pick = p
	var bus := float(BUS.get(name.get_slice("_", 0), 0.7))
	pick.stream = st
	pick.pitch_scale = 1.0 + randf_range(-PITCH, PITCH)
	pick.volume_db = linear_to_db(maxf(volume * bus * gain, 0.0001))
	pick.play()
