class_name GBot
extends RefCounted
## 혼자 연습할 때의 동료이자 밸런스 시뮬레이션용 플레이어.


## 사람과 겹치지 않는 공구함 (혼자 연습의 동료용)
static func pick_kit(taken: Array) -> Array:
	var prefer := ["gun", "cannon", "cold", "magnet", "shock", "flame", "oil", "sniper", "signal", "spike"]
	var kit := []
	for t in prefer:
		if kit.size() < GData.KIT_SIZE and not taken.has(t):
			kit.append(t)
	for t in prefer:
		if kit.size() < GData.KIT_SIZE and not kit.has(t):
			kit.append(t)
	return kit


const DAMAGE := ["gun", "cannon", "shock", "flame", "sniper", "crane", "welder", "cryo", "scrap", "steam"]
static var use_reactions := true      # 시뮬레이션: false 면 상태 없는 포탑 위주 (반응을 안 쓰는 팀)


## 손패에서 4장: 화력 2 + 팀원 상태와 반응이 맞는 것 우선
static func pick_hand(m: GMatch, seat: int) -> void:
	var p: Dictionary = m.players[seat]
	if bool(p["picked"]) or (p["hand"] as Array).is_empty():
		return
	var team_st := {}
	for i in m.players.size():
		if i == seat:
			continue
		for k in m.players[i]["kit"]:
			var st := str(GData.tower_stats(k, 1, "")["st"])
			if st != "":
				team_st[st] = true
	var prefer := ["gun", "cannon", "shock", "flame", "sniper", "cold", "oil", "magnet", "spike", "signal"]
	var scored := []
	for k in p["hand"]:
		var st := str(GData.tower_stats(k, 1, "")["st"])
		var v := 10.0 - prefer.find(k) * 0.5 if prefer.has(k) else 5.0
		if not use_reactions:
			v += 6.0 if not GData.leaves_status(k) else -6.0
		else:
			for o in team_st:
				if st != "" and GData.reaction_of(st, o) != "":
					v += 3.0
		scored.append([v, k])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var kit := []
	if str(p["lock"]) != "":
		kit.append(p["lock"])
	var dmg_rows := scored.filter(func(r): return DAMAGE.has(r[1]) and (use_reactions or not GData.leaves_status(r[1])))      # 화력 2장 먼저
	for row in dmg_rows.slice(0, 2):
		if kit.size() < GData.KIT_SIZE and not kit.has(row[1]):
			kit.append(row[1])
	for row in scored:
		if kit.size() >= GData.KIT_SIZE:
			break
		if not kit.has(row[1]):
			kit.append(row[1])
	m.apply(seat, {"op": "pick", "v": kit})


## 준비 단계에서 할 일을 모두 하고 준비 완료한다.
## suggest_only: 혼자 연습의 동료는 길을 직접 바꾸지 않고, 미리보기로 제안만 한다 (돌려준 값이 제안).
static func play_prep(m: GMatch, seat: int, use_roads := true, suggest_only := false) -> Dictionary:
	pick_hand(m, seat)
	_chip_joints(m, seat)
	for k in m.drafts.keys():      # 내 길로 들어오는 합류 제안은 받아 준다
		var d: Dictionary = m.drafts[k]
		if int(k) != seat and int(d.get("merge", -1)) >= 0 and m.lane_owner(int(d["merge"])) == seat:
			m.apply(seat, {"op": "edit", "e": int(d["e"]), "path": d["path"]})
	if not m.offer.is_empty() and int(m.players[seat]["mat"]) >= int(m.offer["cost"]):      # 새 입구 합류 제안은 받아 준다
		m.apply(seat, {"op": "edit", "e": int(m.offer["e"]), "path": m.offer["path"]})
	_spend(m, seat)      # 포탑을 먼저 놓고, 그 포탑의 사거리 안으로 길을 꺾는다
	_support(m, seat)
	var suggestion := {}
	if use_roads:
		for _n in 3:
			var e := best_road(m, seat)
			if e.is_empty():
				break
			if suggest_only:
				if m.apply(seat, {"op": "draft", "e": e["e"], "path": Board.flat(e["path"])}) == "":
					suggestion = e
				break
			if m.apply(seat, {"op": "edit", "e": e["e"], "path": Board.flat(e["path"])}) != "":
				break
	_repair(m, seat)
	m.apply(seat, {"op": "ready", "v": true})
	return suggestion


## 역할대로 팀을 돕는다: 보급은 남은 돈을 나눠 주고 보급품 투하, 정비는 팀원 포탑에 투자
static func _support(m: GMatch, seat: int) -> void:
	var others := []
	for i in m.players.size():
		if i != seat and bool(m.players[i]["online"]):
			others.append(i)
	if others.is_empty():
		return
	var poor: int = others[0]
	for i in others:
		if int(m.players[i]["gold"]) < int(m.players[poor]["gold"]):
			poor = i
	match m.role_of(seat):
		"supply":
			if not bool(m.players[seat].get("r_used", false)):
				m.apply(seat, {"op": "role", "to": poor})
			var spare := int(m.players[seat]["gold"]) / 2 / 10 * 10
			if spare >= 40:
				m.apply(seat, {"op": "give", "to": poor, "n": spare})
		"mech":
			for id in m.towers.keys():
				var t: Dictionary = m.towers[id]
				if int(t["owner"]) == seat or GData.is_joint(str(t["type"])) or int(m.players[seat]["gold"]) < 60:
					continue
				if m.next_up_cost(t) > 0:
					m.apply(seat, {"op": "invest", "id": id})


## 전투 중 역할 능력 (웨이브당 1번): 적이 본부 가까이 몰리면 쓴다
static func combat_ability(m: GMatch, seat: int) -> void:
	if m.phase != "combat" or bool(m.players[seat].get("r_used", false)) or m.enemies.size() < 4:
		return
	var cc := Vector2(GData.CASTLE.get_center())
	var near := []
	for en in m.enemies:
		if m._pos(en).distance_to(cc) < 12.0:
			near.append(en)
	if near.size() < 3:
		return
	match m.role_of(seat):
		"chief":
			var en: Dictionary = near[0]
			var path: Array = m.board.paths[int(en["e"])]
			var ci := mini(int(float(en["dist"])) + 2, path.size() - 2)
			m.apply(seat, {"op": "role", "x": path[ci].x, "y": path[ci].y})
		"mech":
			var best := -1
			for id in m.towers:
				if not GMatch.is_trap(m.towers[id]) and (best < 0 or int(m.towers[id]["spent"]) > int(m.towers[best]["spent"])):
					best = id
			if best >= 0:
				m.apply(seat, {"op": "role", "id": best})
		"fire":
			m.apply(seat, {"op": "role"})


## 팀원이 세운 합동 설비 기초에 보탠다 (혼자서는 완성할 수 없으니)
static func _chip_joints(m: GMatch, seat: int) -> void:
	for id in m.towers.keys():
		var t: Dictionary = m.towers[id]
		if not GData.is_joint(str(t["type"])) or bool(t.get("done", false)):
			continue
		for _n in 4:
			if bool(t.get("done", false)) or int(m.players[seat]["gold"]) < 140:
				break
			if m.apply(seat, {"op": "chip", "id": id}) != "":
				break


## 보상 투표: 본부가 많이 다쳤으면 회복, 아니면 골드
static func vote(m: GMatch, seat: int) -> void:
	m.apply(seat, {"op": "vote", "v": "heal" if m.hp < 70 else "gold"})


static func _repair(m: GMatch, seat: int) -> void:
	for id in m.towers:
		var t: Dictionary = m.towers[id]
		if int(t["owner"]) == seat and GMatch.is_trap(t) and int(t["uses"]) < 10:
			m.apply(seat, {"op": "repair", "id": id})


static func _want(m: GMatch, seat: int, mine: Array) -> String:
	var kit: Array = m.players[seat]["kit"]
	var counts := {}
	for t in mine:
		counts[t["type"]] = int(counts.get(t["type"], 0)) + 1
	var order := []
	for t in DAMAGE:
		if kit.has(t):
			order.append(t)
	if order.is_empty():
		order = [kit[0]]
	var want: String = order[mine.size() % order.size()]
	for sup in ["cold", "magnet", "oil", "signal", "searchlight", "generator"]:
		if kit.has(sup) and not counts.has(sup) and mine.size() >= 2 + ["cold", "magnet", "oil", "signal", "searchlight", "generator"].find(sup):
			return sup
	if kit.has("spike") and int(counts.get("spike", 0)) < 1 + mine.size() / 5 and mine.size() >= 2:
		return "spike"
	return want


static func _spend(m: GMatch, seat: int) -> void:
	for _guard in 14:
		var gold: int = m.players[seat]["gold"]
		var mine := []
		for id in m.towers:
			if int(m.towers[id]["owner"]) == seat:
				mine.append(m.towers[id])
		var want := _want(m, seat, mine)
		if mine.size() >= 4:
			var up := _cheapest_upgrade(mine)
			if not up.is_empty() and gold >= int(up["cost"]):
				var br := "b" if up["type"] != "cold" else "a"
				if not use_reactions and GData.branch_status(up["type"], br):
					br = "a" if br == "b" else "b"
				if m.apply(seat, {"op": "upgrade", "id": up["id"], "branch": br}) == "":
					continue
		if gold < int(GData.TOWERS[want]["cost"]):
			return
		var c := best_cell(m, want, seat)
		if c.x < 0 or m.apply(seat, {"op": "build", "type": want, "x": c.x, "y": c.y}) != "":
			return


static func _cheapest_upgrade(mine: Array) -> Dictionary:
	var best := {}
	for t in mine:
		if int(t["lv"]) >= 3 or t["type"] == "signal":
			continue
		var cost: int = GData.TOWERS[t["type"]]["up"][int(t["lv"]) - 1]
		if best.is_empty() or cost < int(best["cost"]):
			best = {"id": t["id"], "type": t["type"], "cost": cost}
	return best


## 자기 입구 쪽을 맡는다 (좌석 번호 = 입구 번호)
static func best_cell(m: GMatch, type: String, seat: int) -> Vector2i:
	var s := GData.tower_stats(type, 1, "")
	var radius: float = maxf(float(s["range"]), 1.5)
	var cells := m.tower_cells()
	var lane_i := _weak_lane(m, seat)
	var lane: Array = [m.board.paths[lane_i]]
	var best := Vector2i(-1, -1)
	var best_n := -1
	if bool(s["trap"]):      # 함정: 내 길의 본부 쪽 절반, 굽은 곳
		var p: Array = m.board.paths[lane_i]
		for i in range(p.size() / 3, p.size() - 1):
			var c: Vector2i = p[i]
			if m.board.can_build(c, cells, m.theme(), true) == "":
				var bend := 1 if i > 0 and i < p.size() - 1 and (p[i + 1] - c) != (c - p[i - 1]) else 0
				var n := bend * 10 + i
				if n > best_n:
					best_n = n
					best = c
		return best
	for y in GData.H:
		for x in GData.W:
			var c := Vector2i(x, y)
			if m.board.can_build(c, cells, m.theme()) != "":
				continue
			var n := Board.coverage(c, radius, lane)
			if type == "signal":      # 내 포탑 옆
				n = 0
				for id in m.towers:
					var t: Dictionary = m.towers[id]
					if int(t["owner"]) == seat and Vector2(int(t["x"]), int(t["y"])).distance_to(Vector2(c)) <= float(s["range"]):
						n += 3
			if n > best_n:
				best_n = n
				best = c
	return best if best_n > 0 else Vector2i(-1, -1)


## 내 입구가 기본, 다른 입구가 훨씬 허술하면 그쪽 (유령 숲 새 입구 등)
static func _weak_lane(m: GMatch, seat: int) -> int:
	var n := m.board.paths.size()
	var cover := []
	for e in n:
		var c := 0
		for id in m.towers:
			var t: Dictionary = m.towers[id]
			if GMatch.is_trap(t) or t["type"] == "signal":
				continue
			c += Board.coverage(Vector2i(int(t["x"]), int(t["y"])), m.tower_range(t), [m.board.paths[e]])
		cover.append(c)
	var mine := seat % n
	var weakest := 0
	for e in n:
		if int(cover[e]) < int(cover[weakest]):
			weakest = e
	return weakest if int(cover[weakest]) * 2 + 4 < int(cover[mine]) else mine


## 포탑 사거리 안 길 칸을 가장 많이 늘리는 다시 그리기 (자재 안에서)
static func best_road(m: GMatch, seat: int) -> Dictionary:
	var mat := int(m.players[seat]["mat"])
	var best := {}
	var best_gain := 0.0
	for e in m.board.paths.size():
		for i in m.board.paths[e].size():
			for kind in Board.SHAPES:
				for side in [1, -1]:
					var path := m.board.candidate(e, i, kind, side)
					if path.is_empty():
						continue
					var r := m.check_route(seat, e, path)
					if r.has("err") or int(r["cost"]) > mat or not (r["moves"] as Array).is_empty():
						continue
					var gain := float(gain_of(m, e, path, -1)) / maxf(float(r["cost"]), 1.0)
					if gain > best_gain:
						best_gain = gain
						best = {"e": e, "i": i, "kind": kind, "side": side, "path": path, "cost": r["cost"]}
	return best if best_gain >= 0.5 else {}


## 길을 바꿨을 때 사거리 안에 들어오는 길 칸 증가량 (only >= 0 이면 그 포탑만)
static func gain_of(m: GMatch, e: int, path: Array, only := -1) -> int:
	var trial: Array = m.board.paths.duplicate()
	trial[e] = path
	var total := 0
	for id in m.towers:
		if only >= 0 and id != only:
			continue
		var t: Dictionary = m.towers[id]
		if GMatch.is_trap(t) or t["type"] == "signal":
			continue
		var c := Vector2i(int(t["x"]), int(t["y"]))
		var r := m.tower_range(t)
		total += Board.coverage(c, r, trial) - Board.coverage(c, r, m.board.paths)
	return total
