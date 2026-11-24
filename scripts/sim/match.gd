class_name GMatch
extends RefCounted
## 경기 판정의 기준. 호스트만 apply/step 을 부르고, 손님은 to_data 사본을 받아 그리기만 한다.

var board := Board.new()
var phase := "prep"     # prep | combat | reward | over
var wave := 1
var hp := GData.CASTLE_HP
var players: Array = [] # {name, gold, mat, kit, ready, online, used, dmg, kills, slow, support, ...}
var towers: Dictionary = {}  # id -> {id, owner, type, x, y, lv, branch, spent, prio, cd, uses, heat, fresh}
var enemies: Array = []      # {id, type, e, dist, hp, max, slow, slow_t, shred, oil, sh, ...}
var drafts: Dictionary = {}  # 자리 -> 길 미리보기 {e, path(평평한 배열), cost}: 그 길은 그 사람 색으로 잠긴다
var plan: Array = []         # 이번 웨이브 구성 [입구, 적, 수, 간격, 시작]
var seed_ := 0
var summary: Dictionary = {} # 지난 웨이브 결과 {wave, leaks[], gold}
var _wave_leaks: Array = []
var cleared := false
var failed_wave := 0
var time := 0.0
var version := 0             # 건물·골드 등 구조가 바뀔 때마다 증가
var fx: Array = []           # 그리기용 일회성 효과
var gate_dmg: Array = [0, 0] # 입구별 성 피해
var leaks: Dictionary = {}   # 성에 도착한 적 종류별 수
var speed := 1               # 전투 배속 (2배는 접속 중인 전원 동의)
var ice_t: Dictionary = {}   # 보스가 남긴 빙판 칸 -> 남은 시간
var hp_log: Array = []       # 웨이브마다 끝났을 때 본부 내구도 (결과 화면)
var tower_log: Dictionary = {}  # 포탑 id -> [종류, 단계, 갈래, 주인, 피해, 처치] (결과 화면의 가장 일 많이 한 포탑)
var undo_flags: Array = []   # 손님 사본: 자리별 되돌리기 가능 여부

var _queue: Array = []
var _rq: Array = []          # 손님 사본: 아직 안 나온 적 [입구, 종류, 수]
var _can_call := false       # 손님 쪽 사본: 호스트가 알려준 일찍 부르기 가능 여부
var is_copy := false
var _wave_t := 0.0
var _next_id := 1
var _undo: Dictionary = {}   # 자리 -> 같은 준비 단계의 길 수정 기록 (호스트만)


func _init(names: Array = [], kits: Array = [], seed_value := -1) -> void:
	if names.is_empty():
		return
	GData.use_layout(names.size())
	var lanes := GData.lanes_for(names.size())
	board = Board.new(lanes)
	gate_dmg = []
	gate_dmg.resize(lanes)
	gate_dmg.fill(0)
	seed_ = seed_value if seed_value >= 0 else randi() % 1000000
	for i in names.size():
		var kit: Array = (kits[i] as Array).duplicate() if i < kits.size() and kit_ok(kits[i]) else GData.DEFAULT_KIT.duplicate()
		players.append({"name": str(names[i]), "col": i, "gold": GData.START_GOLD, "mat": GData.MAT_START, "kit": kit,
			"ready": false, "online": true, "used": false, "dmg": 0.0, "kills": 0, "slow": 0.0, "support": 0,
			"fast": false, "free_up": 0, "vote": "", "call": false, "roads": 0})
	_make_plan()


static func kit_ok(kit) -> bool:
	if not kit is Array or (kit as Array).size() != GData.KIT_SIZE:
		return false
	var seen := {}
	for t in kit:
		if not GData.TOWERS.has(str(t)) or seen.has(str(t)):
			return false
		seen[str(t)] = true
	return true


func theme() -> int:
	return GData.theme_of(wave)


func cap() -> int:
	return GData.max_path(wave)


## 지금 웨이브의 입구별 적 구성
func wave_plan() -> Array:
	return plan


## 아직 안 나온 적 [입구, 종류, 수]
func _queue_rows() -> Array:
	if is_copy:
		return _rq
	var by := {}
	var out := []
	for q in _queue:
		var key := "%d|%s" % [int(q["e"]), q["type"]]
		if not by.has(key):
			by[key] = [int(q["e"]), str(q["type"]), 0]
			out.append(by[key])
		by[key][2] += 1
	return out


func queued() -> int:
	var n := 0
	for row in _queue_rows():
		n += int(row[2])
	return n


## 이번 웨이브에 남은 적 (나온 적 + 아직 안 나온 적) [입구, 종류, 수]
func remaining() -> Array:
	var by := {}
	var out := []
	for en in enemies:
		var key := "%d|%s" % [int(en["e"]), en["type"]]
		if not by.has(key):
			by[key] = [int(en["e"]), str(en["type"]), 0]
			out.append(by[key])
		by[key][2] += 1
	for row in _queue_rows():
		var key := "%d|%s" % [int(row[0]), row[1]]
		if not by.has(key):
			by[key] = [int(row[0]), str(row[1]), 0]
			out.append(by[key])
		by[key][2] += int(row[2])
	return out


func _make_plan() -> void:
	var weak := -1
	if not summary.is_empty() and summary.has("leaks"):
		var least := 1 << 30
		for e in mini(board.paths.size(), (summary["leaks"] as Array).size()):
			var d := int(summary["leaks"][e])
			if d < least:
				least = d
				weak = e
	plan = GData.make_wave(wave, players.size(), board.paths.size(), seed_, weak)


func tower_cells() -> Dictionary:
	var out := {}
	for id in towers:
		out[Vector2i(int(towers[id]["x"]), int(towers[id]["y"]))] = id
	return out


## 길을 막는 칸 (함정은 길 위에 있어도 된다)
func blockers() -> Dictionary:
	var out := {}
	for id in towers:
		var t: Dictionary = towers[id]
		if not is_trap(t):
			out[Vector2i(int(t["x"]), int(t["y"]))] = id
	return out


static func is_trap(t: Dictionary) -> bool:
	return bool(GData.TOWERS[t["type"]]["lv"][0].get("trap", false))


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
	if op == "speed":
		return _speed(seat, bool(c.get("v", false)))
	if op == "vote":
		return _vote(seat, str(c.get("v", "")))
	if op == "call":
		return _call(seat, bool(c.get("v", true)))
	if phase != "prep":
		return "준비 단계에서만 할 수 있어요"
	var err := ""
	match op:
		"build": err = _build(seat, c)
		"move": err = _move(seat, c)
		"sell": err = _sell(seat, c)
		"upgrade": err = _upgrade(seat, c)
		"repair": err = _repair(seat, c)
		"edit": err = _edit(seat, c)
		"draft": err = _draft(seat, c)
		"undo": err = _undo_edit(seat)
		"kit": err = _set_kit(seat, c)
		"ready": return _set_ready(seat, bool(c.get("v", true)))
		_: return "알 수 없는 요청이에요"
	if err == "":
		version += 1
		if op != "draft":
			players[seat]["ready"] = false
	return err


## 2배는 전원이 동의해야 켜지고, 누구든 1배로 되돌릴 수 있다
func _speed(seat: int, want_fast: bool) -> String:
	players[seat]["fast"] = want_fast
	if want_fast:
		speed = 2 if fast_votes() >= online_count() else speed
	else:
		speed = 1
		for p in players:
			p["fast"] = false
	version += 1
	return ""


## 지금 다음 웨이브를 일찍 부를 수 있는지: 이번 웨이브 적이 다 나왔고, 보스·마지막 웨이브가 아닐 때
func can_call() -> bool:
	if is_copy:
		return _can_call
	return phase == "combat" and _queue.is_empty() and not enemies.is_empty() \
		and wave % GData.THEME_LEN != 0 and wave < GData.LAST_WAVE


func call_votes() -> int:
	var n := 0
	for p in players:
		if p["online"] and bool(p.get("call", false)):
			n += 1
	return n


## 일찍 부르기는 접속 중인 전원이 동의해야 한다. 이번 웨이브 골드에 보너스를 얹고 남은 적은 그대로 둔 채 다음 웨이브를 연다.
func _call(seat: int, v: bool) -> String:
	if v and not can_call():
		return "적이 다 나온 뒤에 부를 수 있어요"
	players[seat]["call"] = v
	version += 1
	if v and call_votes() >= online_count():
		_call_early()
	return ""


func _call_early() -> void:
	var bonus := GData.early_bonus(enemies.size())
	var gold := GData.wave_gold(wave)
	for p in players:
		p["gold"] += gold + bonus
		p["mat"] = mini(int(p["mat"]) + GData.MAT_WAVE, GData.MAT_MAX)
		p["call"] = false
	summary = {"wave": wave, "leaks": _wave_leaks.duplicate(), "gold": gold, "reward": "", "early": bonus}
	_log_hp()
	fx.append({"k": "early", "n": bonus})
	_advance()
	_start_wave()


func fast_votes() -> int:
	var n := 0
	for p in players:
		if p["online"] and bool(p.get("fast", false)):
			n += 1
	return n


func online_count() -> int:
	var n := 0
	for p in players:
		if p["online"]:
			n += 1
	return n


func _set_kit(seat: int, c: Dictionary) -> String:
	var kit = c.get("v", [])
	if not kit_ok(kit):
		return "포탑 %d종을 골라 주세요" % GData.KIT_SIZE
	for id in towers:
		if int(towers[id]["owner"]) == seat and not (kit as Array).has(towers[id]["type"]):
			return "이미 지은 포탑은 공구함에서 뺄 수 없어요"
	players[seat]["kit"] = (kit as Array).duplicate()
	return ""


func _build(seat: int, c: Dictionary) -> String:
	var type := str(c.get("type", ""))
	if not GData.TOWERS.has(type):
		return "없는 포탑이에요"
	if not (players[seat]["kit"] as Array).has(type):
		return "공구함에 없는 포탑이에요"
	var cell := Vector2i(int(c.get("x", -1)), int(c.get("y", -1)))
	var trap: bool = GData.TOWERS[type]["lv"][0].get("trap", false)
	var err := board.can_build(cell, tower_cells(), theme(), trap)
	if err != "":
		return err
	var cost: int = GData.TOWERS[type]["cost"]
	if players[seat]["gold"] < cost:
		return "골드가 부족해요"
	players[seat]["gold"] -= cost
	var id := _next_id
	_next_id += 1
	var s := GData.tower_stats(type, 1, "")
	towers[id] = {"id": id, "owner": seat, "type": type, "x": cell.x, "y": cell.y, "lv": 1, "branch": "",
		"spent": cost, "prio": "strong" if type == "sniper" else "first", "cd": 0.0, "uses": int(s["uses"]), "heat": 0.0, "fresh": true}
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
	var cells := tower_cells()
	cells.erase(Vector2i(int(t["x"]), int(t["y"])))
	var err := board.can_build(cell, cells, theme(), is_trap(t))
	if err != "":
		return err
	t["x"] = cell.x
	t["y"] = cell.y
	return ""


## 판매: 같은 준비 단계에 지은 포탑은 전액 환불 (실수 되돌리기)
func _sell(seat: int, c: Dictionary) -> String:
	var t := _mine(seat, c)
	if t.is_empty():
		return "내 포탑만 팔 수 있어요"
	players[seat]["gold"] += sell_value(t)
	towers.erase(int(t["id"]))
	return ""


func sell_value(t: Dictionary) -> int:
	return int(t["spent"]) if bool(t.get("fresh", false)) else int(floor(int(t["spent"]) * GData.SELL_RATE))


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
	if int(players[seat].get("free_up", 0)) > 0:      # 보상으로 받은 무료 강화
		players[seat]["free_up"] = int(players[seat]["free_up"]) - 1
		cost = 0
	if players[seat]["gold"] < cost:
		return "골드가 부족해요"
	players[seat]["gold"] -= cost
	t["spent"] = int(t["spent"]) + cost
	t["lv"] = lv + 1
	if lv == 2:
		t["branch"] = branch
	if is_trap(t):
		t["uses"] = int(GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))["uses"])
	return ""


func _repair(seat: int, c: Dictionary) -> String:
	var t := _mine(seat, c)
	if t.is_empty() or not is_trap(t):
		return "내 함정만 고칠 수 있어요"
	var full := int(GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))["uses"])
	if int(t["uses"]) >= full:
		return "고칠 데가 없어요"
	if int(players[seat]["mat"]) < GData.TRAP_REPAIR:
		return "공사 자재가 부족해요"
	players[seat]["mat"] = int(players[seat]["mat"]) - GData.TRAP_REPAIR
	t["uses"] = full
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


## 다시 그린 길을 검사한다. 내 포탑이 막으면 옆 칸으로 옮길 자리를 같이 찾는다.
## 결과 {path, cost, moves:[[id, x, y]]} 또는 {err}
func check_route(seat: int, e: int, path: Array) -> Dictionary:
	if e < 0 or e >= board.paths.size():
		return {"err": "없는 길이에요"}
	for s in drafts:
		if int(s) != seat and int(drafts[s]["e"]) == e:
			return {"err": "%s 님이 이 길을 그리는 중이에요 · 핑으로 의견을 보내 주세요" % players[int(s)]["name"]}
	var blk := blockers()
	var moves: Array = []
	var taken := {}
	for c in path:
		if not blk.has(c) or board.paths[e].has(c):
			continue
		var t: Dictionary = towers[blk[c]]
		if int(t["owner"]) != seat:
			return {"err": "%s 님 포탑이 막고 있어요 · 옮겨 달라고 핑을 보내 보세요" % players[int(t["owner"])]["name"]}
		var spot := _free_beside(c, path, taken)
		if spot.x < 0:
			return {"err": "막고 있는 내 포탑을 옮길 빈칸이 없어요"}
		taken[spot] = true
		moves.append([t["id"], spot.x, spot.y])
		blk.erase(c)
	var sync := board.synced(e, path)
	var lanes: Array = board.paths.duplicate()
	lanes[e] = path
	for o in sync:
		lanes[o] = sync[o]
	var err := board.validate(e, path, blk, theme(), cap(), lanes)
	if err != "":
		return {"err": err}
	for o in sync:
		err = board.validate(o, sync[o], blk, theme(), cap(), lanes)
		if err != "":
			return {"err": "합류한 %d번 길: %s" % [o + 1, err]}
	return {"path": path, "cost": board.cost_of(e, path, theme()), "moves": moves, "sync": sync}


func _free_beside(c: Vector2i, path: Array, taken: Dictionary) -> Vector2i:
	var cells := tower_cells()
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n: Vector2i = c + d
		if taken.has(n) or path.has(n):
			continue
		if board.can_build(n, cells, theme()) == "":
			return n
	return Vector2i(-1, -1)


static func _path_arg(c: Dictionary) -> Array:
	var raw = c.get("path", [])
	if not raw is Array:
		return []
	return Board.unflat(raw)


## 미리보기: 길의 두 점 사이를 새로 그린 경로. 그 길은 확정·취소 전까지 내 색으로 잠긴다.
func _draft(seat: int, c: Dictionary) -> String:
	if not c.has("e"):
		drafts.erase(seat)
		return ""
	var e := int(c.get("e", -1))
	var r := check_route(seat, e, _path_arg(c))
	if r.has("err"):
		return str(r["err"])
	drafts[seat] = {"e": e, "path": Board.flat(r["path"]), "cost": int(r["cost"]), "moves": r["moves"]}
	return ""


## 확정: 늘어난 칸만큼 자재를 쓰고, 줄이면 돌려받는다. 같은 준비 단계 안에서는 되돌릴 수 있다.
func _edit(seat: int, c: Dictionary) -> String:
	var e := int(c.get("e", -1))
	var path := _path_arg(c)
	if path.is_empty() and drafts.has(seat):
		e = int(drafts[seat]["e"])
		path = Board.unflat(drafts[seat]["path"])
	if path.is_empty():
		return "먼저 길을 그려 주세요"
	for s in drafts.keys():      # 동료의 제안을 내 자재로 확정할 수 있다
		if int(s) != seat and int(drafts[s]["e"]) == e and drafts[s]["path"] == Board.flat(path):
			drafts.erase(s)
	var r := check_route(seat, e, path)
	if r.has("err"):
		return str(r["err"])
	var cost := int(r["cost"])
	if cost > int(players[seat]["mat"]):
		return "공사 자재가 부족해요 (%d 필요)" % cost
	var back := []
	for mv in r["moves"]:
		var t: Dictionary = towers[int(mv[0])]
		back.append([t["id"], t["x"], t["y"]])
		t["x"] = int(mv[1])
		t["y"] = int(mv[2])
	if not _undo.has(seat):
		_undo[seat] = []
	var olds := {e: board.paths[e]}
	for o in r["sync"]:
		olds[o] = board.paths[o]
		board.paths[o] = r["sync"][o]
	_undo[seat].append({"e": e, "old": board.paths[e], "olds": olds, "cost": cost, "moves": back})
	board.paths[e] = r["path"]
	players[seat]["mat"] = clampi(int(players[seat]["mat"]) - cost, 0, GData.MAT_MAX)
	drafts.erase(seat)
	players[seat]["roads"] = int(players[seat].get("roads", 0)) + 1
	for p in players:
		p["ready"] = false
	return ""


func _log_hp() -> void:
	if hp_log.size() < wave:
		hp_log.resize(wave)
	hp_log[wave - 1] = hp


func _log_tower(s: Dictionary, owner: int, dmg: float, kill: bool) -> void:
	var id := int(s.get("tid", -1))
	if id < 0 or not towers.has(id):
		return
	var t: Dictionary = towers[id]
	var row: Array = tower_log.get(id, [t["type"], 1, "", owner, 0.0, 0])
	row[1] = int(t["lv"])
	row[2] = str(t["branch"])
	row[4] = float(row[4]) + dmg
	if kill:
		row[5] = int(row[5]) + 1
	tower_log[id] = row


func can_undo(seat: int) -> bool:
	return _undo.has(seat) and not (_undo[seat] as Array).is_empty()


func _undo_edit(seat: int) -> String:
	if not can_undo(seat):
		return "되돌릴 길 수정이 없어요"
	var u: Dictionary = _undo[seat].pop_back()
	var e := int(u["e"])
	var blk := blockers()
	for mv in u["moves"]:
		if towers.has(int(mv[0])):
			var t: Dictionary = towers[int(mv[0])]
			blk.erase(Vector2i(int(t["x"]), int(t["y"])))
	var lanes: Array = board.paths.duplicate()
	var olds: Dictionary = u.get("olds", {e: u["old"]})
	for o in olds:
		lanes[o] = olds[o]
	for o in olds:
		if board.validate(o, olds[o], blk, theme(), 999, lanes) != "":
			_undo[seat].append(u)
			return "그사이 바뀐 것이 있어 되돌릴 수 없어요"
	for o in olds:
		board.paths[o] = olds[o]
	for mv in u["moves"]:
		if towers.has(int(mv[0])):
			towers[int(mv[0])]["x"] = int(mv[1])
			towers[int(mv[0])]["y"] = int(mv[2])
	players[seat]["mat"] = clampi(int(players[seat]["mat"]) + int(u["cost"]), 0, GData.MAT_MAX)
	return ""


func undo_ready(seat: int) -> bool:
	if not is_copy:
		return can_undo(seat)
	return seat < undo_flags.size() and bool(undo_flags[seat])


## 테마 보스를 넘기면 팀 보상을 투표로 고른다. 동점이면 목록 순서가 앞선 것.
func _vote(seat: int, v: String) -> String:
	if phase != "reward":
		return "지금은 보상을 고를 때가 아니에요"
	if not GData.REWARDS.has(v):
		return "없는 보상이에요"
	players[seat]["vote"] = v
	version += 1
	var counts := {}
	for p in players:
		if not p["online"]:
			continue
		if str(p["vote"]) == "":
			return ""
		counts[p["vote"]] = int(counts.get(p["vote"], 0)) + 1
	var best := ""
	for k in GData.REWARDS:
		if counts.has(k) and (best == "" or int(counts[k]) > int(counts[best])):
			best = k
	match best:
		"heal": hp = mini(GData.CASTLE_HP, hp + GData.REWARD_HEAL)
		"gold":
			for p in players:
				p["gold"] = int(p["gold"]) + GData.REWARD_GOLD
		"up":
			for p in players:
				p["free_up"] = int(p.get("free_up", 0)) + 1
	summary["reward"] = best
	for p in players:
		p["vote"] = ""
	phase = "prep"
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
	drafts = {}
	_undo = {}
	_wave_t = 0.0
	_queue = []
	for g in plan:
		for n in int(g[2]):
			_queue.append({"t": float(g[4]) + n * float(g[3]), "e": mini(int(g[0]), board.paths.size() - 1), "type": str(g[1])})
	_queue.sort_custom(func(a, b): return a["t"] < b["t"])
	_wave_leaks = []
	_wave_leaks.resize(board.paths.size())
	_wave_leaks.fill(0)
	for p in players:
		p["ready"] = false
		p["used"] = false
		p["call"] = false
	for id in towers:
		towers[id]["fresh"] = false
	version += 1


func _spawn(type: String, e: int, dist := 0.0, hp_ratio := 1.0) -> Dictionary:
	var d: Dictionary = GData.ENEMIES[type]
	var max_hp: float = float(d["hp"]) * GData.hp_mul * GData.wave_hp(wave, players.size())
	var en := {"id": _next_id, "type": type, "e": e, "dist": dist, "hp": max_hp * hp_ratio, "max": max_hp * hp_ratio,
		"slow": 0.0, "slow_t": 0.0, "shred": 0.0, "shred_t": 0.0, "oil": 0.0, "sh": 0.0, "cell": -1, "sk": 0.0, "done": []}
	_next_id += 1
	enemies.append(en)
	return en


func step(dt := GData.TICK) -> void:
	if phase != "combat":
		return
	time += dt
	_wave_t += dt
	while not _queue.is_empty() and _queue[0]["t"] <= _wave_t and enemies.size() < GData.MAX_ALIVE:
		var q: Dictionary = _queue.pop_front()
		_spawn(q["type"], q["e"])
	for k in ice_t.keys():
		ice_t[k] = float(ice_t[k]) - dt
		if float(ice_t[k]) <= 0.0:
			ice_t.erase(k)
	_move_enemies(dt)
	if phase == "over":
		return
	_enemy_skills(dt)
	_fire(dt)
	if _queue.is_empty() and enemies.is_empty():
		_finish_wave()


func on_ice(c: Vector2i) -> bool:
	return ice_t.has(c) or (GData.pond_state(theme()) == "ice" and GData.is_pond(c))


func on_lava(c: Vector2i) -> bool:
	return theme() >= 3 and GData.CRACKS.has(c)


func _move_enemies(dt: float) -> void:
	for en in enemies.duplicate():
		if not enemies.has(en):
			continue
		for k in ["slow", "shred"]:
			var tk: String = k + "_t"
			if float(en[tk]) > 0.0:
				en[tk] = float(en[tk]) - dt
				if float(en[tk]) <= 0.0:
					en[k] = 0.0
		en["oil"] = maxf(float(en["oil"]) - dt, 0.0)
		var d: Dictionary = GData.ENEMIES[en["type"]]
		var path: Array = board.paths[en["e"]]
		var ci := clampi(int(float(en["dist"]) + 0.5), 0, path.size() - 1)
		var cell: Vector2i = path[ci]
		var boost := 1.0
		if on_ice(cell):
			boost = float(d.get("ice", GData.ICE_SPEED))
		var slow := float(en["slow"]) * (1.0 - float(d.get("slow_res", 0.0)))
		en["dist"] += float(d["speed"]) * GData.SPEED_MUL * boost * (1.0 - slow) * dt
		if on_lava(cell) and not bool(d.get("fireproof", false)):
			en["hp"] = float(en["hp"]) - float(en["max"]) * GData.LAVA_RATE * dt
			if float(en["hp"]) <= 0.0:
				_die(en, -1)
				continue
		if ci != int(en["cell"]):        # 새 칸에 들어섰다: 함정·빙판 자국
			en["cell"] = ci
			if float(d.get("trail", 0.0)) > 0.0:
				ice_t[cell] = float(d["trail"])
			_trap(en, cell)
			if not enemies.has(en):
				continue
		if en["dist"] >= path.size() - 1 + 0.6:
			hp -= int(d["hit"])
			gate_dmg[int(en["e"])] += int(d["hit"])
			if int(en["e"]) < _wave_leaks.size():
				_wave_leaks[int(en["e"])] += 1
			leaks[en["type"]] = int(leaks.get(en["type"], 0)) + 1
			fx.append({"k": "hit", "n": int(d["hit"]), "e": int(en["e"])})
			enemies.erase(en)
			version += 1
			if hp <= 0:
				hp = 0
				_lose()
				return


func _trap(en: Dictionary, cell: Vector2i) -> void:
	for id in towers:
		var t: Dictionary = towers[id]
		if int(t["x"]) != cell.x or int(t["y"]) != cell.y or not is_trap(t) or int(t["uses"]) <= 0:
			continue
		var s := GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))
		s["tid"] = int(t["id"])
		t["uses"] = int(t["uses"]) - 1
		if int(t["uses"]) <= 0:
			version += 1
		fx.append({"k": "shot", "ty": t["type"], "x": cell.x + 0.5, "y": cell.y + 0.5, "tx": cell.x + 0.5, "ty2": cell.y + 0.5, "r": 0.5})
		_hurt(en, s, int(t["owner"]), true)
		return


## 적 능력: 회복, 보호막, 보스 기술
func _enemy_skills(dt: float) -> void:
	for en in enemies.duplicate():
		if not enemies.has(en):
			continue
		var d: Dictionary = GData.ENEMIES[en["type"]]
		var at := _pos(en)
		if float(d.get("heal", 0.0)) > 0.0:
			for o in enemies:
				if o != en and _pos(o).distance_to(at) <= float(d["heal_r"]):
					o["hp"] = minf(float(o["max"]), float(o["hp"]) + float(d["heal"]) * GData.hp_mul * dt)
		if float(d.get("guard", 0.0)) > 0.0:
			for o in enemies:
				if o != en and _pos(o).distance_to(at) <= 2.0:
					o["sh"] = minf(float(d["guard"]) * GData.hp_mul, float(o["sh"]) + 10.0 * GData.hp_mul * dt)
		if d.has("overheat"):
			en["sk"] = float(en["sk"]) + dt
			var oh: Array = d["overheat"]
			if float(en["sk"]) >= float(oh[0]):
				en["sk"] = 0.0
				for id in towers:
					var t: Dictionary = towers[id]
					if (Vector2(int(t["x"]), int(t["y"])) + Vector2(0.5, 0.5)).distance_to(at) <= float(oh[1]):
						t["heat"] = float(oh[2])
				fx.append({"k": "heat", "x": at.x, "y": at.y, "r": float(oh[1])})
		if d.has("clone") and not (en["done"] as Array).has("clone") and not bool(en.get("cl", false)) \
				and float(en["hp"]) <= float(en["max"]) * float(d["clone"]):
			en["done"].append("clone")
			var lane := board.paths.size() - 1
			var c := _spawn(en["type"], lane, 0.0, 0.35)
			c["cl"] = true
			fx.append({"k": "spawn", "e": lane})
		if d.has("drops"):
			var dr: Array = d["drops"]
			for r in dr[0]:
				var key := "drop%s" % r
				if float(r) > 0.0 and not (en["done"] as Array).has(key) and float(en["hp"]) <= float(en["max"]) * float(r):
					en["done"].append(key)
					for i in int(dr[2]):
						_spawn(str(dr[1]), int(en["e"]), maxf(float(en["dist"]) - 0.08 * i, 0.0))


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
		if float(t.get("heat", 0.0)) > 0.0:
			t["heat"] = float(t["heat"]) - dt
			continue
		t["cd"] = float(t["cd"]) - dt
		if t["cd"] > 0.0:
			continue
		var s := GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))
		s["tid"] = int(t["id"])
		if bool(s["support"]) or bool(s["trap"]):
			continue
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
				if enemies.has(en) and _pos(en).distance_to(at) <= float(s["range"]):
					_hurt(en, s, owner)
			continue
		if bool(s["line"]):      # 사거리 끝까지 일직선 관통
			var dir := (hit_at - at).normalized()
			var tip := at + dir * float(s["range"])
			fx.append({"k": "shot", "ty": t["type"], "x": at.x, "y": at.y, "tx": tip.x, "ty2": tip.y, "r": 0.0})
			for en in enemies.duplicate():
				var rel := _pos(en) - at
				var along := rel.dot(dir)
				if enemies.has(en) and (en == target or (along >= 0.0 and along <= float(s["range"]) and absf(rel.cross(dir)) <= 0.45)):
					_hurt(en, s, owner)
			continue
		if int(s["chain"]) > 0:      # 연쇄 번개: 가까운 적으로 튄다
			var hit := [target]
			var from := hit_at
			fx.append({"k": "shot", "ty": t["type"], "x": at.x, "y": at.y, "tx": from.x, "ty2": from.y, "r": 0.0})
			for _n in int(s["chain"]) - 1:
				var nxt := {}
				var best := float(s["jump"])
				for en in enemies:
					if hit.has(en) or is_hidden(en):
						continue
					var dd := _pos(en).distance_to(from)
					if dd <= best:
						best = dd
						nxt = en
				if nxt.is_empty():
					break
				var to := _pos(nxt)
				fx.append({"k": "shot", "ty": t["type"], "x": from.x, "y": from.y, "tx": to.x, "ty2": to.y, "r": 0.0})
				hit.append(nxt)
				from = to
			for en in hit:
				if enemies.has(en):
					_hurt(en, s, owner)
			continue
		fx.append({"k": "shot", "ty": t["type"], "x": at.x, "y": at.y, "tx": hit_at.x, "ty2": hit_at.y, "r": s["splash"]})
		if float(s["splash"]) > 0.0:
			for en in enemies.duplicate():
				if enemies.has(en) and _pos(en).distance_to(hit_at) <= float(s["splash"]):
					_hurt(en, s, owner)
		else:
			_hurt(target, s, owner)


func _pick(at: Vector2, radius: float, prio: String) -> Dictionary:
	var best := {}
	var best_v := -INF
	for en in enemies:
		if is_hidden(en) or _pos(en).distance_to(at) > radius:
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
	return str(GData.THEMES[theme()]["zone"])


## 이번 웨이브 모래바람 중심 (준비 단계에 공개, 웨이브마다 자리가 바뀜)
func sand_spot() -> Vector2:
	if theme() != 2 or GData.SAND_SPOTS.is_empty():
		return Vector2(-99, -99)
	return GData.SAND_SPOTS[absi(hash([seed_, wave])) % GData.SAND_SPOTS.size()]


func _signals() -> Array:
	var out := []
	for id in towers:
		var t: Dictionary = towers[id]
		if t["type"] == "signal" and float(t.get("heat", 0.0)) <= 0.0:
			out.append(t)
	return out


## 환경·신호탑까지 반영한 사거리
func tower_range(t: Dictionary) -> float:
	var r: float = GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))["range"]
	var at := Vector2(int(t["x"]), int(t["y"])) + Vector2(0.5, 0.5)
	if t["type"] != "signal" and not is_trap(t):
		var buff := 0.0
		for sg in _signals():
			var ss := GData.tower_stats("signal", int(sg["lv"]), str(sg["branch"]))
			if (Vector2(int(sg["x"]), int(sg["y"])) + Vector2(0.5, 0.5)).distance_to(at) <= float(ss["range"]) + 0.01:
				buff = maxf(buff, float(ss["buff"]))
		r *= 1.0 + buff
	if at.distance_to(sand_spot()) <= GData.SAND_RADIUS:
		r *= GData.SAND_RANGE
	if not is_trap(t) and GData.is_high(Vector2i(int(t["x"]), int(t["y"]))):
		r += GData.HIGH_RANGE
	return r


func _revealed(at: Vector2) -> bool:
	for sg in _signals():
		var ss := GData.tower_stats("signal", int(sg["lv"]), str(sg["branch"]))
		if (Vector2(int(sg["x"]), int(sg["y"])) + Vector2(0.5, 0.5)).distance_to(at) <= float(ss["range"]):
			return true
	return false


func _marked(at: Vector2) -> float:
	var m := 0.0
	for sg in _signals():
		var ss := GData.tower_stats("signal", int(sg["lv"]), str(sg["branch"]))
		if float(ss["mark"]) > 0.0 and (Vector2(int(sg["x"]), int(sg["y"])) + Vector2(0.5, 0.5)).distance_to(at) <= float(ss["range"]):
			m = maxf(m, float(ss["mark"]))
	return m


## 조준할 수 없는 상태: 유령병(신호탑 근처면 실체화), 땅속의 굴착 벌레
func is_hidden(en: Dictionary) -> bool:
	if en.has("gh"):
		return bool(en["gh"])
	var d: Dictionary = GData.ENEMIES[en["type"]]
	var id := int(en["id"])
	if d.has("phase"):
		var ph: Array = d["phase"]
		if fmod(time + id * 0.37, float(ph[0])) < float(ph[1]):
			return not _revealed(_pos(en))
	if d.has("burrow"):
		var bw: Array = d["burrow"]
		return fmod(time + id * 0.53, float(bw[0])) < float(bw[1])
	return false


func is_ghost(en: Dictionary) -> bool:
	return is_hidden(en)


func _hurt(en: Dictionary, s: Dictionary, owner: int, from_trap := false) -> void:
	if not from_trap and is_hidden(en):
		return
	var d: Dictionary = GData.ENEMIES[en["type"]]
	if float(s.get("oil", 0.0)) > 0.0:
		en["oil"] = maxf(float(en["oil"]), float(s["oil"]))
	if float(s.get("shred", 0.0)) > 0.0:      # 자석탑: 방어력을 잠시 깎는다 (겹치면 큰 쪽)
		en["shred"] = maxf(float(en.get("shred", 0.0)), float(s["shred"]))
		en["shred_t"] = 3.0
	var raw := float(s["dmg"])
	if bool(s.get("fire", false)):
		if bool(d.get("fireproof", false)):
			raw = 0.0
		elif float(en["oil"]) > 0.0:
			raw *= 3.0
	if int(s.get("chain", 0)) > 0 and float(en["slow"]) > 0.0:
		raw *= 2.0
	raw *= 1.0 + _marked(_pos(en))
	var base_armor: float = float(d["armor"]) * (1.0 - float(en.get("shred", 0.0)))
	var armor: float = maxf(base_armor - float(s["pierce"]), 0.0)
	var dmg: float = maxf(raw - armor, raw * 0.25) if raw > 0.0 else 0.0
	if float(en["sh"]) > 0.0 and dmg > 0.0:      # 수송차 보호막이 먼저 막는다
		var absorbed := minf(float(en["sh"]), dmg)
		en["sh"] = float(en["sh"]) - absorbed
		dmg -= absorbed
	dmg = minf(dmg, float(en["hp"]))
	en["hp"] = float(en["hp"]) - dmg
	players[owner]["dmg"] += dmg
	_log_tower(s, owner, dmg, float(en["hp"]) <= 0.0)
	if dmg >= 12.0:
		var at := _pos(en)
		fx.append({"k": "num", "x": at.x, "y": at.y, "n": roundi(dmg)})
	if float(s["slow"]) > 0.0:
		_chill(en, float(s["slow"]), 1.4, owner)
	if float(en["hp"]) <= 0.0:
		_die(en, owner)


func _die(en: Dictionary, owner: int) -> void:
	if not enemies.has(en):
		return
	var d: Dictionary = GData.ENEMIES[en["type"]]
	if owner >= 0:
		players[owner]["kills"] += 1
	var at := _pos(en)
	fx.append({"k": "kill", "x": at.x, "y": at.y, "big": en["type"] == "heavy" or GData.is_boss(en["type"])})
	enemies.erase(en)
	if d.has("split"):
		var sp: Array = d["split"]
		for i in int(sp[1]):
			_spawn(str(sp[0]), int(en["e"]), maxf(float(en["dist"]) - 0.3 * i, 0.0))
	if d.has("drops"):
		var dr: Array = d["drops"]
		if (dr[0] as Array).has(0.0):
			for i in int(dr[2]):
				_spawn(str(dr[1]), int(en["e"]), maxf(float(en["dist"]) - 0.08 * i, 0.0))


func _chill(en: Dictionary, amount: float, dur: float, owner: int) -> void:
	var v := minf(maxf(float(en["slow"]), amount), GData.SLOW_CAP)   # 겹쳐도 상한까지만
	en["slow"] = v
	en["slow_t"] = maxf(float(en["slow_t"]), dur)
	players[owner]["slow"] += dur * 0.1


func _finish_wave() -> void:
	var gold := GData.wave_gold(wave)
	for p in players:
		p["gold"] += gold
		p["mat"] = mini(int(p["mat"]) + GData.MAT_WAVE, GData.MAT_MAX)
		p["call"] = false
	summary = {"wave": wave, "leaks": _wave_leaks.duplicate(), "gold": gold, "reward": ""}
	_log_hp()
	if wave >= GData.LAST_WAVE:
		cleared = true
		phase = "over"
		version += 1
		return
	var boss := wave % GData.THEME_LEN == 0
	if boss:
		for p in players:
			p["vote"] = ""
	_advance()
	phase = "reward" if boss else "prep"
	version += 1


## 다음 웨이브로: 테마가 바뀌면 지형 사건, 구성 새로 만들기
func _advance() -> void:
	wave += 1
	while board.extra < mini(theme(), GData.EXTRA_PATHS.size()):      # 테마가 바뀔 때마다 새 입구
		board.paths.append((GData.EXTRA_PATHS[board.extra] as Array).duplicate())
		board.extra += 1
		board.opened = true
		gate_dmg.append(0)
		fx.append({"k": "open", "e": board.paths.size() - 1})
	_make_plan()


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
		drafts.erase(seat)
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
		ts.append([t["id"], t["owner"], t["type"], t["x"], t["y"], t["lv"], t["branch"], t["spent"], t["prio"],
			int(t.get("uses", 0)), snappedf(float(t.get("heat", 0.0)), 0.1), bool(t.get("fresh", false))])
	var dr := {}
	for s in drafts:
		dr[str(s)] = drafts[s]
	var undo := []
	for s in players.size():
		undo.append(can_undo(s))
	return {"ph": phase, "w": wave, "hp": hp, "pl": players, "tw": ts, "dr": dr, "sm": summary, "wp": plan, "sd": seed_,
		"cl": cleared, "fw": failed_wave, "tm": time, "v": version, "pa": board.to_data(), "op": board.opened, "ex": board.extra, "gd": gate_dmg,
		"lk": leaks, "sp": speed, "cc": can_call(), "al": enemies.size(), "un": undo, "it": _ice_data(), "hl": hp_log, "rq": _queue_rows(), "tl": _tower_log_data()}


func _ice_data() -> Array:
	var out := []
	for c in ice_t:
		out.append(c.x)
		out.append(c.y)
	return out


func load_data(d: Dictionary) -> void:
	is_copy = true
	phase = str(d["ph"])
	wave = int(d["w"])
	hp = int(d["hp"])
	var pl: Array = d["pl"]
	if GData.LAYOUT != ("v4" if pl.size() >= 3 else "v2"):
		GData.use_layout(pl.size())
	players = pl
	for p in players:
		p["gold"] = int(p["gold"])
		p["mat"] = int(p.get("mat", 0))
		p["col"] = int(p.get("col", 0))
		p["kills"] = int(p["kills"])
		p["support"] = int(p["support"])
		p["free_up"] = int(p.get("free_up", 0))
		var kit: Array = []
		for t in p.get("kit", GData.DEFAULT_KIT):
			kit.append(str(t))
		p["kit"] = kit
	towers = {}
	for r in d["tw"]:
		towers[int(r[0])] = {"id": int(r[0]), "owner": int(r[1]), "type": str(r[2]), "x": int(r[3]), "y": int(r[4]),
			"lv": int(r[5]), "branch": str(r[6]), "spent": int(r[7]), "prio": str(r[8]), "cd": 0.0,
			"uses": int(r[9]) if r.size() > 9 else 0, "heat": float(r[10]) if r.size() > 10 else 0.0, "fresh": bool(r[11]) if r.size() > 11 else false}
	drafts = {}
	var dr: Dictionary = d.get("dr", {})
	for s in dr:
		var v: Dictionary = dr[s]
		drafts[int(s)] = {"e": int(v["e"]), "path": v["path"], "cost": int(v["cost"]), "moves": v.get("moves", [])}
	plan = d.get("wp", [])
	seed_ = int(d.get("sd", 0))
	summary = d.get("sm", {})
	if summary.has("wave"):
		summary["wave"] = int(summary["wave"])
	cleared = bool(d["cl"])
	failed_wave = int(d["fw"])
	time = float(d["tm"])
	version = int(d["v"])
	board.load_data(d["pa"])
	board.opened = bool(d.get("op", false))
	board.extra = int(d.get("ex", 0))
	gate_dmg = []
	for v in d["gd"]:
		gate_dmg.append(int(v))
	leaks = d["lk"]
	speed = int(d.get("sp", 1))
	_can_call = bool(d.get("cc", false))
	undo_flags = d.get("un", [])
	_rq = d.get("rq", [])
	hp_log = []
	for v in d.get("hl", []):
		hp_log.append(int(v) if v != null else 0)
	tower_log = {}
	for row in d.get("tl", []):
		tower_log[int(row[0])] = [str(row[1]), int(row[2]), str(row[3]), int(row[4]), float(row[5]), int(row[6])]
	ice_t = {}
	var it: Array = d.get("it", [])
	for k in range(0, it.size() - 1, 2):
		ice_t[Vector2i(int(it[k]), int(it[k + 1]))] = 1.0


func enemies_data() -> Array:
	var out := []
	for en in enemies:
		out.append([en["id"], en["type"], en["e"], snappedf(en["dist"], 0.01), roundi(en["hp"]), roundi(en["max"]), snappedf(en["slow"], 0.01),
			is_hidden(en), snappedf(float(en.get("shred", 0.0)), 0.01), float(en.get("oil", 0.0)) > 0.0, roundi(float(en.get("sh", 0.0))), snappedf(float(en.get("sk", 0.0)), 0.1)])
	return out


func load_enemies(rows: Array) -> void:
	enemies = []
	for r in rows:
		enemies.append({"id": int(r[0]), "type": str(r[1]), "e": int(r[2]), "dist": float(r[3]), "hp": float(r[4]),
			"max": float(r[5]), "slow": float(r[6]), "slow_t": 0.0, "gh": bool(r[7]), "shred": float(r[8]) if r.size() > 8 else 0.0, "shred_t": 0.0,
			"oil": 1.0 if r.size() > 9 and bool(r[9]) else 0.0, "sh": float(r[10]) if r.size() > 10 else 0.0, "sk": float(r[11]) if r.size() > 11 else 0.0,
			"cell": -1, "done": []})


## 결과 화면용: 피해가 큰 포탑 3개만 보낸다
func _tower_log_data() -> Array:
	var ids := tower_log.keys()
	ids.sort_custom(func(a, b): return float(tower_log[a][4]) > float(tower_log[b][4]))
	var out := []
	for id in ids.slice(0, 3):
		var r: Array = tower_log[id]
		out.append([id, r[0], r[1], r[2], r[3], snappedf(float(r[4]), 1.0), r[5]])
	return out
