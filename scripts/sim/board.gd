class_name Board
extends RefCounted
## 격자와 적 경로. 길 조각 교체와 설치 유효성 검사를 맡는다.

var paths: Array = []   # 입구별 Array[Vector2i]


func _init() -> void:
	for raw in GData.BASE_PATHS:
		var p: Array = []
		for c in raw:
			p.append(Vector2i(int(c[0]), int(c[1])))
		paths.append(p)


static func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GData.W and c.y < GData.H


static func is_castle(c: Vector2i) -> bool:
	return GData.CASTLE.has_point(c)


func is_path(c: Vector2i) -> bool:
	for p in paths:
		if p.has(c):
			return true
	return false


func can_build(c: Vector2i, towers: Dictionary) -> String:
	if not in_bounds(c):
		return "맵 밖이에요"
	if is_castle(c):
		return "성 자리예요"
	if is_path(c):
		return "길 위에는 지을 수 없어요"
	if towers.has(c):
		return "이미 포탑이 있어요"
	return ""


## 조각을 끼운 새 경로. 실패하면 {err}
func reroute(e: int, i: int, kind: String, side: int, towers: Dictionary) -> Dictionary:
	if e < 0 or e >= paths.size() or not GData.PIECES.has(kind) or abs(side) != 1:
		return {"err": "잘못된 길 조각이에요"}
	var p: Array = paths[e]
	var span: int = GData.PIECES[kind]["span"]
	var depth: int = GData.PIECES[kind]["depth"]
	if i < 0 or i + span >= p.size():
		return {"err": "이 구간에는 놓을 수 없어요"}
	var a: Vector2i = p[i]
	var b: Vector2i = p[i + span]
	var dir: Vector2i = p[i + 1] - a
	for j in range(1, span + 1):
		if p[i + j] != a + dir * j:
			return {"err": "곧은 구간에만 놓을 수 있어요"}
	var n := Vector2i(-dir.y, dir.x) * side
	var out: Array = p.slice(0, i + 1)
	for k in range(1, depth + 1):
		out.append(a + n * k)
	for j in range(1, span + 1):
		out.append(a + dir * j + n * depth)
	for k in range(depth - 1, 0, -1):
		out.append(b + n * k)
	out.append_array(p.slice(i + span))
	var err := validate(e, out, towers)
	if err != "":
		return {"err": err}
	return {"path": out}


## 기획서 5.4 설치 유효 조건
func validate(e: int, path: Array, towers: Dictionary) -> String:
	if path.size() > GData.MAX_PATH:
		return "경로 길이 상한(%d칸)을 넘어요" % GData.MAX_PATH
	if path.is_empty() or path[0] != paths[e][0]:
		return "입구와 이어지지 않아요"
	var seen := {}
	for idx in path.size():
		var c: Vector2i = path[idx]
		if not in_bounds(c):
			return "맵 경계를 벗어나요"
		if is_castle(c):
			return "성과 겹쳐요"
		if towers.has(c):
			return "포탑과 겹쳐요"
		if seen.has(c):
			return "길이 자기 자신과 겹쳐요"
		seen[c] = true
		if idx > 0:
			var step: Vector2i = c - path[idx - 1]
			if abs(step.x) + abs(step.y) != 1:
				return "길이 끊겨요"
		for other in paths.size():
			if other != e and paths[other].has(c):
				return "다른 입구의 길과 겹쳐요"
	var last: Vector2i = path[path.size() - 1]
	var touching := false
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_castle(last + d):
			touching = true
	return "" if touching else "성까지 이어지지 않아요"


## 마우스 위치에서 가장 그럴듯한 조각 자리. 없으면 {}
func best_edit(mouse: Vector2, kind: String, towers: Dictionary, reach := 2.6) -> Dictionary:
	var best := {}
	var best_d := reach
	for e in paths.size():
		for i in paths[e].size():
			for side in [1, -1]:
				var r := reroute(e, i, kind, side, towers)
				if r.has("err"):
					continue
				var center := _bulge_center(paths[e], r["path"])
				var d := center.distance_to(mouse)
				if d < best_d:
					best_d = d
					best = {"e": e, "i": i, "kind": kind, "side": side, "path": r["path"]}
	return best


func _bulge_center(old: Array, now: Array) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for c in now:
		if not old.has(c):
			sum += Vector2(c) + Vector2(0.5, 0.5)
			n += 1
	return sum / max(n, 1)


## 사거리 안에 들어오는 길 칸 수 (길 효율 미리보기)
static func coverage(cell: Vector2i, radius: float, path_list: Array) -> int:
	var center := Vector2(cell) + Vector2(0.5, 0.5)
	var n := 0
	for p in path_list:
		for c in p:
			if center.distance_to(Vector2(c) + Vector2(0.5, 0.5)) <= radius:
				n += 1
	return n


static func pos_on(path: Array, dist: float) -> Vector2:
	var i := clampi(int(dist), 0, path.size() - 1)
	var j := mini(i + 1, path.size() - 1)
	var a := Vector2(path[i]) + Vector2(0.5, 0.5)
	var b := Vector2(path[j]) + Vector2(0.5, 0.5)
	return a.lerp(b, clampf(dist - i, 0.0, 1.0))


func to_data() -> Array:
	var out := []
	for p in paths:
		var flat := []
		for c in p:
			flat.append(c.x)
			flat.append(c.y)
		out.append(flat)
	return out


func load_data(d: Array) -> void:
	paths = []
	for flat in d:
		var p: Array = []
		for k in range(0, flat.size(), 2):
			p.append(Vector2i(int(flat[k]), int(flat[k + 1])))
		paths.append(p)
