class_name GMatch
extends RefCounted
## 경기 판정의 기준. 호스트만 apply/step 을 부르고, 손님은 to_data 사본을 받아 그리기만 한다.

var board := Board.new()
var phase := "prep"     # prep | combat | over
var wave := 1
var hp := GData.CASTLE_HP
var players: Array = [] # {name, gold, ready, online, used, dmg, kills, slow, support}
var towers: Dictionary = {}  # id -> {id, owner, type, x, y, lv, branch, spent, prio, cd}
var enemies: Array = []      # {id, type, e, dist, hp, max, slow, slow_t}
var edits_left := GData.EDITS_PER_THEME
var road_owner := 0
var draft: Dictionary = {}   # 길 담당자의 공유 미리보기
var cleared := false
var failed_wave := 0
var time := 0.0
var version := 0             # 건물·골드 등 구조가 바뀔 때마다 증가
var fx: Array = []           # 그리기용 일회성 효과
var gate_dmg: Array = [0, 0] # 입구별 성 피해
var leaks: Dictionary = {}   # 성에 도착한 적 종류별 수

var _queue: Array = []
var _wave_t := 0.0
var _next_id := 1


func _init(names: Array = []) -> void:
	for i in names.size():
		var n = names[i]
		players.append({"name": str(n), "col": i, "gold": GData.START_GOLD, "ready": false, "online": true, "used": false,
			"dmg": 0.0, "kills": 0, "slow": 0.0, "support": 0})


func tower_cells() -> Dictionary:
	var out := {}
	for id in towers:
		out[Vector2i(int(towers[id]["x"]), int(towers[id]["y"]))] = id
	return out


func apply(seat: int, c: Dictionary) -> String:
	if seat < 0 or seat >= players.size():
		return "자리가 없어요"
	if phase == "over":
		return "경기가 끝났어요"
	var op := str(c.get("op", ""))
	if op == "ability":
		return _ability(seat, c)
	if op == "prio":
		return _prio(seat, c)
	if phase != "prep":
		return "준비 단계에서만 할 수 있어요"
	var err := ""
	match op:
		"build": err = _build(seat, c)
		"move": err = _move(seat, c)
		"sell": err = _sell(seat, c)
		"upgrade": err = _upgrade(seat, c)
		"edit": err = _edit(seat, c)
		"draft": err = _draft(seat, c)
		"ready": return _set_ready(seat, bool(c.get("v", true)))
		_: return "알 수 없는 요청이에요"
	if err == "":
		version += 1
		if op != "draft":
			players[seat]["ready"] = false
	return err


func _build(seat: int, c: Dictionary) -> String:
	var type := str(c.get("type", ""))
	if not GData.TOWERS.has(type):
		return "없는 포탑이에요"
	var cell := Vector2i(int(c.get("x", -1)), int(c.get("y", -1)))
	var err := board.can_build(cell, tower_cells())
	if err != "":
		return err
	var cost: int = GData.TOWERS[type]["cost"]
	if players[seat]["gold"] < cost:
		return "골드가 부족해요"
	players[seat]["gold"] -= cost
	var id := _next_id
	_next_id += 1
	towers[id] = {"id": id, "owner": seat, "type": type, "x": cell.x, "y": cell.y, "lv": 1, "branch": "",
		"spent": cost, "prio": "first", "cd": 0.0}
	return ""


func _mine(seat: int, c: Dictionary) -> Dictionary:
	var id := int(c.get("id", -1))
	if not towers.has(id) or int(towers[id]["owner"]) != seat:
		return {}
	return towers[id]


func _move(seat: int, c: Dictionary) -> String:
	var t := _mine(seat, c)
	if t.is_empty():
		return "내 포탑만 옮길 수 있어요"
	var cell := Vector2i(int(c.get("x", -1)), int(c.get("y", -1)))
	var err := board.can_build(cell, tower_cells())
	if err != "":
		return err
	t["x"] = cell.x
	t["y"] = cell.y
	return ""


func _sell(seat: int, c: Dictionary) -> String:
	var t := _mine(seat, c)
	if t.is_empty():
		return "내 포탑만 팔 수 있어요"
	players[seat]["gold"] += int(floor(int(t["spent"]) * GData.SELL_RATE))
	towers.erase(int(t["id"]))
	return ""


func _upgrade(seat: int, c: Dictionary) -> String:
	var t := _mine(seat, c)
	if t.is_empty():
		return "내 포탑만 강화할 수 있어요"
	var lv := int(t["lv"])
	if lv >= 3:
		return "이미 최고 단계예요"
	var branch := str(c.get("branch", ""))
	if lv == 2 and branch != "a" and branch != "b":
		return "강화 방향을 골라 주세요"
	var cost: int = GData.TOWERS[t["type"]]["up"][lv - 1]
	if players[seat]["gold"] < cost:
		return "골드가 부족해요"
	players[seat]["gold"] -= cost
	t["spent"] = int(t["spent"]) + cost
	t["lv"] = lv + 1
	if lv == 2:
		t["branch"] = branch
	return ""


func _prio(seat: int, c: Dictionary) -> String:
	var t := _mine(seat, c)
	if t.is_empty():
		return "내 포탑만 바꿀 수 있어요"
	var v := str(c.get("v", ""))
	if not ["first", "strong", "near"].has(v):
		return "잘못된 우선순위예요"
	t["prio"] = v
	version += 1
	return ""


func _edit(seat: int, c: Dictionary) -> String:
	if seat != road_owner:
		return "이번 웨이브의 길 담당자만 확정할 수 있어요"
	if edits_left <= 0:
		return "길 개조 기회가 없어요"
	var r := board.reroute(int(c.get("e", -1)), int(c.get("i", -1)), str(c.get("kind", "")), int(c.get("side", 0)), tower_cells())
	if r.has("err"):
		return str(r["err"])
	board.paths[int(c["e"])] = r["path"]
	edits_left -= 1
	draft = {}
	for p in players:
		p["ready"] = false
	return ""


func _draft(seat: int, c: Dictionary) -> String:
	if seat != road_owner:
		return "길 담당자만 미리보기를 공유해요"
	if not c.has("e"):
		draft = {}
		return ""
	var r := board.reroute(int(c.get("e", -1)), int(c.get("i", -1)), str(c.get("kind", "")), int(c.get("side", 0)), tower_cells())
	if r.has("err"):
		return str(r["err"])
	draft = {"e": int(c["e"]), "i": int(c["i"]), "kind": str(c["kind"]), "side": int(c["side"])}
	return ""


func _set_ready(seat: int, v: bool) -> String:
	players[seat]["ready"] = v
	version += 1
	var any := false
	for p in players:
		if p["online"]:
			any = true
			if not p["ready"]:
				return ""
	if any:
		_start_wave()
	return ""


func _ability(seat: int, c: Dictionary) -> String:
	if phase != "combat":
		return "전투 중에만 쓸 수 있어요"
	if players[seat]["used"]:
		return "이번 웨이브에 이미 썼어요"
	var at := Vector2(float(c.get("x", -99)), float(c.get("y", -99)))
	if at.x < 0 or at.y < 0 or at.x > GData.W or at.y > GData.H:
		return "맵 안을 골라 주세요"
	players[seat]["used"] = true
	players[seat]["support"] += 1
	for en in enemies:
		if _pos(en).distance_to(at) <= GData.ABILITY_RADIUS:
			_chill(en, GData.ABILITY_SLOW, GData.ABILITY_TIME, seat)
	fx.append({"k": "ability", "x": at.x, "y": at.y, "o": seat})
	version += 1
	return ""


func _start_wave() -> void:
	phase = "combat"
	draft = {}
	_wave_t = 0.0
	_queue = []
	for g in GData.wave_groups(wave):
		for n in int(g[2]):
			_queue.append({"t": float(g[4]) + n * float(g[3]), "e": int(g[0]), "type": str(g[1])})
	_queue.sort_custom(func(a, b): return a["t"] < b["t"])
	for p in players:
		p["ready"] = false
		p["used"] = false
	version += 1


func step(dt := GData.TICK) -> void:
	if phase != "combat":
		return
	time += dt
	_wave_t += dt
	while not _queue.is_empty() and _queue[0]["t"] <= _wave_t and enemies.size() < GData.MAX_ALIVE:
		var q: Dictionary = _queue.pop_front()
		var d: Dictionary = GData.ENEMIES[q["type"]]
		var max_hp: float = float(d["hp"]) * GData.hp_mul * GData.wave_hp(wave)
		enemies.append({"id": _next_id, "type": q["type"], "e": q["e"], "dist": 0.0, "hp": max_hp, "max": max_hp,
			"slow": 0.0, "slow_t": 0.0})
		_next_id += 1
	_move_enemies(dt)
	if phase == "over":
		return
	_fire(dt)
	if _queue.is_empty() and enemies.is_empty():
		_finish_wave()


func _move_enemies(dt: float) -> void:
	for idx in range(enemies.size() - 1, -1, -1):
		var en: Dictionary = enemies[idx]
		if en["slow_t"] > 0.0:
			en["slow_t"] -= dt
			if en["slow_t"] <= 0.0:
				en["slow"] = 0.0
		var d: Dictionary = GData.ENEMIES[en["type"]]
		var zone := _zone()
		var cell := Vector2i(_pos(en))
		var boost := GData.ICE_SPEED if zone == "ice" and _in_zones(cell, GData.ICE_ZONES) else 1.0
		en["dist"] += float(d["speed"]) * boost * (1.0 - float(en["slow"])) * dt
		if zone == "lava" and _in_zones(cell, GData.LAVA_ZONES):
			en["hp"] = float(en["hp"]) - float(en["max"]) * GData.LAVA_RATE * dt
			if float(en["hp"]) <= 0.0:
				enemies.remove_at(idx)
				continue
		if en["dist"] >= board.paths[en["e"]].size() - 1 + 0.6:
			hp -= int(d["hit"])
			gate_dmg[int(en["e"])] += int(d["hit"])
			leaks[en["type"]] = int(leaks.get(en["type"], 0)) + 1
			fx.append({"k": "hit", "n": int(d["hit"]), "e": int(en["e"])})
			enemies.remove_at(idx)
			version += 1
			if hp <= 0:
				hp = 0
				_lose()
				return


func _lose() -> void:
	phase = "over"
	failed_wave = wave
	enemies = []
	_queue = []
	version += 1


func _pos(en: Dictionary) -> Vector2:
	return Board.pos_on(board.paths[en["e"]], float(en["dist"]))


func _fire(dt: float) -> void:
	for id in towers:
		var t: Dictionary = towers[id]
		t["cd"] = float(t["cd"]) - dt
		if t["cd"] > 0.0:
			continue
		var s := GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))
		s["range"] = tower_range(t)
		var at := Vector2(int(t["x"]), int(t["y"])) + Vector2(0.5, 0.5)
		var target := _pick(at, float(s["range"]), str(t["prio"]))
		if target.is_empty():
			continue
		t["cd"] = float(s["cd"])
		var hit_at := _pos(target)
		var owner := int(t["owner"])
		if bool(s["aura"]):      # 범위 안 전부
			fx.append({"k": "shot", "ty": t["type"], "x": at.x, "y": at.y, "tx": at.x, "ty2": at.y, "r": s["range"]})
			for en in enemies.duplicate():
				if _pos(en).distance_to(at) <= float(s["range"]):
					_hurt(en, s, owner)
			continue
		if bool(s["line"]):      # 사거리 끝까지 일직선 관통
			var dir := (hit_at - at).normalized()
			var tip := at + dir * float(s["range"])
			fx.append({"k": "shot", "ty": t["type"], "x": at.x, "y": at.y, "tx": tip.x, "ty2": tip.y, "r": 0.0})
			for en in enemies.duplicate():
				var rel := _pos(en) - at
				var along := rel.dot(dir)
				if en == target or (along >= 0.0 and along <= float(s["range"]) and absf(rel.cross(dir)) <= 0.45):
					_hurt(en, s, owner)
			continue
		fx.append({"k": "shot", "ty": t["type"], "x": at.x, "y": at.y, "tx": hit_at.x, "ty2": hit_at.y, "r": s["splash"]})
		if float(s["splash"]) > 0.0:
			for en in enemies.duplicate():
				if _pos(en).distance_to(hit_at) <= float(s["splash"]):
					_hurt(en, s, owner)
		else:
			_hurt(target, s, owner)


func _pick(at: Vector2, radius: float, prio: String) -> Dictionary:
	var best := {}
	var best_v := -INF
	for en in enemies:
		if is_ghost(en) or _pos(en).distance_to(at) > radius:
			continue
		var v := 0.0
		match prio:
			"near": v = -_pos(en).distance_to(at)
			"strong": v = float(en["hp"])
			_: v = float(en["dist"]) - board.paths[en["e"]].size()
		if v > best_v:
			best_v = v
			best = en
	return best


func _zone() -> String:
	return str(GData.THEMES[GData.theme_of(wave)]["zone"])


func _in_zones(cell: Vector2i, zones: Array) -> bool:
	for r in zones:
		if r.has_point(cell):
			return true
	return false


## 환경까지 반영한 사거리
func tower_range(t: Dictionary) -> float:
	var r: float = GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))["range"]
	if _zone() == "sand":
		var at := Vector2(int(t["x"]), int(t["y"])) + Vector2(0.5, 0.5)
		if at.distance_to(GData.SAND_CENTER) <= GData.SAND_RADIUS:
			r *= GData.SAND_RANGE
	return r


## 유령 숲: 적 셋 중 하나가 주기적으로 조준 불가. 길을 따라 움직이고 성에 닿으면 피해를 준다.
func is_ghost(en: Dictionary) -> bool:
	if _zone() != "ghost":
		return false
	if en.has("gh"):
		return bool(en["gh"])
	var id := int(en["id"])
	return id % 3 == 0 and fmod(time + id * 0.37, GData.GHOST_CYCLE) < GData.GHOST_TIME


func _hurt(en: Dictionary, s: Dictionary, owner: int) -> void:
	if is_ghost(en):
		return
	var armor: float = maxf(float(GData.ENEMIES[en["type"]]["armor"]) - float(s["pierce"]), 0.0)
	var dmg: float = maxf(float(s["dmg"]) - armor, float(s["dmg"]) * 0.25)
	dmg = minf(dmg, float(en["hp"]))
	en["hp"] = float(en["hp"]) - dmg
	players[owner]["dmg"] += dmg
	if float(s["slow"]) > 0.0:
		_chill(en, float(s["slow"]), 1.4, owner)
	if float(en["hp"]) <= 0.0:
		players[owner]["kills"] += 1
		enemies.erase(en)


func _chill(en: Dictionary, amount: float, dur: float, owner: int) -> void:
	var v := minf(maxf(float(en["slow"]), amount), GData.SLOW_CAP)   # 겹쳐도 상한까지만
	en["slow"] = v
	en["slow_t"] = maxf(float(en["slow_t"]), dur)
	players[owner]["slow"] += dur * 0.1


func _finish_wave() -> void:
	var gold := GData.wave_gold(wave)
	for p in players:
		p["gold"] += gold
	if wave >= GData.LAST_WAVE:
		cleared = true
		phase = "over"
		version += 1
		return
	if wave % GData.THEME_LEN == 0:
		edits_left = GData.EDITS_PER_THEME
	wave += 1
	phase = "prep"
	road_owner = next_online((road_owner + 1) % players.size())
	version += 1


func next_online(from: int) -> int:
	for k in players.size():
		var s := (from + k) % players.size()
		if players[s]["online"]:
			return s
	return from


func set_online(seat: int, on: bool) -> void:
	players[seat]["online"] = on
	if not on:
		players[seat]["ready"] = false
		if road_owner == seat:
			road_owner = next_online(seat)
			draft = {}
	version += 1
	if not on and phase == "prep":
		var all_ready := false
		for p in players:
			if p["online"]:
				all_ready = bool(p["ready"])
				if not all_ready:
					break
		if all_ready:
			_start_wave()


func to_data() -> Dictionary:
	var ts := []
	for id in towers:
		var t: Dictionary = towers[id]
		ts.append([t["id"], t["owner"], t["type"], t["x"], t["y"], t["lv"], t["branch"], t["spent"], t["prio"]])
	return {"ph": phase, "w": wave, "hp": hp, "pl": players, "tw": ts, "ed": edits_left, "ro": road_owner, "dr": draft,
		"cl": cleared, "fw": failed_wave, "tm": time, "v": version, "pa": board.to_data(), "gd": gate_dmg, "lk": leaks}


func load_data(d: Dictionary) -> void:
	phase = str(d["ph"])
	wave = int(d["w"])
	hp = int(d["hp"])
	players = d["pl"]
	for p in players:
		p["gold"] = int(p["gold"])
		p["col"] = int(p.get("col", 0))
		p["kills"] = int(p["kills"])
		p["support"] = int(p["support"])
	towers = {}
	for r in d["tw"]:
		towers[int(r[0])] = {"id": int(r[0]), "owner": int(r[1]), "type": str(r[2]), "x": int(r[3]), "y": int(r[4]),
			"lv": int(r[5]), "branch": str(r[6]), "spent": int(r[7]), "prio": str(r[8]), "cd": 0.0}
	edits_left = int(d["ed"])
	road_owner = int(d["ro"])
	draft = {}
	var dr: Dictionary = d["dr"]
	if not dr.is_empty():
		draft = {"e": int(dr["e"]), "i": int(dr["i"]), "kind": str(dr["kind"]), "side": int(dr["side"])}
	cleared = bool(d["cl"])
	failed_wave = int(d["fw"])
	time = float(d["tm"])
	version = int(d["v"])
	board.load_data(d["pa"])
	gate_dmg = [int(d["gd"][0]), int(d["gd"][1])]
	leaks = d["lk"]


func enemies_data() -> Array:
	var out := []
	for en in enemies:
		out.append([en["id"], en["type"], en["e"], snappedf(en["dist"], 0.01), roundi(en["hp"]), en["max"], snappedf(en["slow"], 0.01), is_ghost(en)])
	return out


func load_enemies(rows: Array) -> void:
	enemies = []
	for r in rows:
		enemies.append({"id": int(r[0]), "type": str(r[1]), "e": int(r[2]), "dist": float(r[3]), "hp": float(r[4]),
			"max": float(r[5]), "slow": float(r[6]), "slow_t": 0.0, "gh": bool(r[7])})
