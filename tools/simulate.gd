extends SceneTree
## 밸런스 확인: 인원별로 포탑만 쓴 팀과 길까지 다시 그린 팀을 비교한다.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		GData.hp_mul = float(args[0])
	if args.size() > 1:
		for k in GData.budget_scale:
			GData.budget_scale[k] = float(GData.budget_scale[k]) * float(args[1])
	print("hp_mul ", GData.hp_mul, " budget x", args[1] if args.size() > 1 else "1")
	var seeds := [11]
	for n in [2, 3, 4]:
		var a := []
		var b := []
		for sd in seeds:
			a.append(_run(n, false, sd))
			b.append(_run(n, true, sd))
		print("%d인 | 포탑만: %s | 포탑+길: %s" % [n, " / ".join(a), " / ".join(b)])
	quit()


func _run(players: int, roads: bool, sd: int) -> String:
	var names := []
	var kits := []
	var pool := [["gun", "cannon", "cold", "magnet", "spike"], ["shock", "flame", "oil", "sniper", "signal"],
		["gun", "shock", "cold", "signal", "spike"], ["cannon", "flame", "oil", "magnet", "sniper"]]
	for i in players:
		names.append("P%d" % i)
		kits.append(pool[i % pool.size()])
	var m := GMatch.new(names, kits, sd)
	var guard := 0
	var worst := ""
	while m.phase != "over" and guard < 600000:
		guard += 1
		if m.phase == "reward":
			for vk in m.players.size():
				m.apply(vk, {"op": "vote", "v": "gold"})
		elif m.phase == "prep":
			for s in players:
				if m.phase == "prep":
					GBot.play_prep(m, s, roads)
			for s in players:          # 길을 고치면 전원 준비가 풀리므로 다시 준비
				if m.phase == "prep":
					m.apply(s, {"op": "ready", "v": true})
		else:
			var before := m.hp
			m.step()
	var lens := []
	for p in m.board.paths:
		lens.append(p.size())
	return "%s W%d 성%d 길%s" % ["O" if m.cleared else "X", m.wave if not m.cleared else 25, m.hp, str(lens)]
