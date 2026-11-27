extends SceneTree
## 초반 피격 확인: 웨이브 1~N 마다 새어 들어온 적 수와 본부 피해
## 사용: godot --headless --path . -s res://tools/early_probe.gd -- [인원들] [시드들] [끝 웨이브] [hp_mul]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var ns := Array(args[0].split(",")).map(func(v): return int(v)) if args.size() > 0 else [2]
	var seeds := Array(args[1].split(",")).map(func(v): return int(v)) if args.size() > 1 else [11, 23, 37]
	var last := int(args[2]) if args.size() > 2 else 8
	if args.size() > 3 and args[3] != "":
		GData.hp_mul = float(args[3])
	if args.size() > 4 and args[4] != "":
		GData.EARLY_HP = Array(args[4].split(",")).map(func(v): return float(v))
	if args.size() > 5 and args[5] != "":
		GData.start_gold_override = int(args[5])
	if args.size() > 6 and args[6] != "":
		GData.EARLY_BUDGET = Array(args[6].split(",")).map(func(v): return float(v))
	if args.size() > 7 and args[7] != "":
		GData.HQ_GUN_AMMO = int(args[7])
	GBot.use_reactions = true
	for n in ns:
		for sd in seeds:
			var names := []
			for i in n:
				names.append("P%d" % i)
			var m := GMatch.new(names, [], sd)
			m.auto_kits()
			var roles := ["fire", "supply", "mech", "chief"]
			for i in n:
				m.players[i]["role"] = roles[i]
			var row := []
			var cur := 1
			var leak0 := 0
			var hp0 := m.hp
			var guard := 0
			while m.phase != "over" and m.wave <= last and guard < 600000:
				guard += 1
				if m.phase == "reward":
					for vk in m.players.size():
						m.apply(vk, {"op": "vote", "v": "gold"})
				elif m.phase == "prep":
					if m.wave != cur:
						row.append("W%d:%d새/-%d" % [cur, m._wave_leak_n if false else _leaks(m) - leak0, hp0 - m.hp])
						leak0 = _leaks(m); hp0 = m.hp; cur = m.wave
					for s in n:
						if m.phase == "prep":
							GBot.play_prep(m, s, true)
					for s in n:
						if m.phase == "prep":
							m.apply(s, {"op": "ready", "v": true})
				else:
					m.step()
			print("%d인 시드%d | %s" % [n, sd, " ".join(row)])
	quit()


func _leaks(m) -> int:
	var t := 0
	for k in m.leaks:
		t += int(m.leaks[k])
	return t
