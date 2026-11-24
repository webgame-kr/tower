extends SceneTree
## 밸런스 확인: 반응을 안 쓰는 팀(상태 없는 포탑 위주)과 반응을 잘 쓰는 팀을 웨이브 25까지 돌린다.
## 목표: 안 쓰는 팀은 웨이브 12 전후, 잘 쓰는 팀은 20 이상.
## 사용: godot --headless --path . -s res://tools/simulate.gd -- [hp_mul] [인원들 예: 2,4] [시드들 예: 11,23]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "":
		GData.hp_mul = float(args[0])
	var ns := [2, 3, 4]
	if args.size() > 1:
		ns = Array(args[1].split(",")).map(func(v): return int(v))
	var seeds := [11, 23]
	if args.size() > 2:
		seeds = Array(args[2].split(",")).map(func(v): return int(v))
	var only := args[3] if args.size() > 3 else ""      # blind / smart 하나만
	print("hp_mul ", GData.hp_mul)
	for n in ns:
		var a := []
		var b := []
		for sd in seeds:
			if only != "smart":
				GBot.use_reactions = false
				a.append(_run(n, sd))
			if only != "blind":
				GBot.use_reactions = true
				b.append(_run(n, sd))
		print("%d인 | 반응 안 씀: %s | 반응 씀: %s" % [n, " / ".join(a), " / ".join(b)])
	quit()


func _run(players: int, sd: int) -> String:
	var names := []
	for i in players:
		names.append("P%d" % i)
	var m := GMatch.new(names, [], sd)
	m.auto_kits()
	var roles := ["fire", "supply", "mech", "chief"]
	for i in players:
		m.players[i]["role"] = roles[i]
	var guard := 0
	while m.phase != "over" and guard < 900000:
		guard += 1
		if m.phase == "reward":
			for vk in m.players.size():
				m.apply(vk, {"op": "vote", "v": "gold"})
		elif m.phase == "prep":
			if not GBot.use_reactions:      # 반응을 안 쓰는 팀: 상태 없는 포탑만
				var plain := GData.unlocked(m.wave).filter(func(k): return not GData.leaves_status(k) and not GData.is_joint(k))
				var order := ["cannon", "gun", "sniper", "crane", "spike", "conveyor", "generator"]
				plain.sort_custom(func(a, b): return order.find(a) < order.find(b))
				for s in players:
					m.players[s]["kit"] = plain.slice(0, GData.KIT_SIZE)
					m.players[s]["picked"] = true
			for s in players:
				if m.phase == "prep":
					GBot.play_prep(m, s, true)
			for s in players:
				if m.phase == "prep":
					m.apply(s, {"op": "ready", "v": true})
		else:
			m.step()
	var rx := 0
	for k in m.rx_log:
		rx += int(m.rx_log[k])
	return "%s W%d 반응%d" % ["O" if m.cleared else "X", m.wave if not m.cleared else 25, rx]
