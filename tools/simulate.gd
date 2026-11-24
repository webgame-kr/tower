extends SceneTree
## 밸런스 확인: 인원별로 포탑만 쓴 팀과 길까지 고친 팀을 비교한다.


func _init() -> void:
	for n in [2, 3, 4]:
		print("%d인 | 포탑만: %s | 포탑+길: %s" % [n, _run(n, false), _run(n, true)])
	quit()


func _run(players: int, roads: bool) -> String:
	var names := []
	for i in players:
		names.append("P%d" % i)
	var m := GMatch.new(names)
	var guard := 0
	while m.phase != "over" and guard < 400000:
		guard += 1
		if m.phase == "reward":
			for vk in m.players.size():
				m.apply(vk, {"op": "vote", "v": "gold"})
		elif m.phase == "prep":
			for s in players:
				if m.phase == "reward":
					for vk in m.players.size():
						m.apply(vk, {"op": "vote", "v": "gold"})
				elif m.phase == "prep":
					GBot.play_prep(m, s, roads)
			for s in players:          # 길을 고치면 전원 준비가 풀리므로 다시 준비
				if m.phase == "reward":
					for vk in m.players.size():
						m.apply(vk, {"op": "vote", "v": "gold"})
				elif m.phase == "prep":
					m.apply(s, {"op": "ready", "v": true})
		else:
			m.step()
	return "%s W%d 성%d %.0f초 포탑%d" % ["성공" if m.cleared else "패배", m.wave, m.hp, m.time, m.towers.size()]
