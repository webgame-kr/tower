extends SceneTree
## 밸런스 확인: 적 체력 배율별로 전략을 비교한다. 길을 고친 팀이 더 오래 버텨야 한다.


func _init() -> void:
	for mul in [1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]:
		GData.hp_mul = mul
		print("체력 x%.1f | 포탑만: %s | 포탑+길: %s" % [mul, _run(false), _run(true)])
	quit()


func _run(roads: bool) -> String:
	var m := GMatch.new(["A", "B"])
	var guard := 0
	while m.phase != "over" and guard < 200000:
		guard += 1
		if m.phase == "prep":
			GBot.play_prep(m, 0, roads)
			if m.phase == "prep":
				GBot.play_prep(m, 1, roads)
			if m.phase == "prep":   # 길을 고치면 전원 준비가 풀리므로 다시 준비
				m.apply(0, {"op": "ready", "v": true})
				m.apply(1, {"op": "ready", "v": true})
		else:
			m.step()
	return "%s W%d 성%d %.0f초" % ["성공" if m.cleared else "패배", m.wave, m.hp, m.time]
