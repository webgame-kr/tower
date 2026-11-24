class_name Board
extends RefCounted
## 격자와 적 경로. 길 다시 그리기와 설치 유효성 검사를 맡는다.

var paths: Array = []   # 입구별 Array[Vector2i]
var opened := false     # 유령 숲의 막힌 땅이 열렸는지


func _init(lanes := 2) -> void:
	for raw in GData.BASE_PATHS.slice(0, lanes):
		paths.append((raw as Array).duplicate())


static func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GData.W and c.y < GData.H


static func is_castle(c: Vector2i) -> bool:
	return GData.CASTLE.has_point(c)


func is_path(c: Vector2i) -> bool:
	for p in paths:
		if p.has(c):
			return true
	return false


func lane_of(c: Vector2i) -> int:
	for e in paths.size():
		if paths[e].has(c):
			return e
	return -1


## 땅 자체가 막혀 있는지 (길과 포탑 공통). 연못은 테마에 따라 다르다.
func ground_err(c: Vector2i, theme: int, for_road: bool) -> String:
	if not in_bounds(c):
		return "맵 밖이에요"
	if is_castle(c):
		return "본부 자리예요"
	if GData.LANDMARK.has_point(c):
		return "랜드마크 구역이에요"
	if GData.ROCKS.has(c):
		return "바위가 있어요"
	if not opened and GData.BLOCKED.has_point(c):
		return "막힌 땅이에요 (유령 숲에서 열려요)"
	if GData.is_pond(c):
		var st := GData.pond_state(theme)
		if st == "dry" or (st == "ice" and for_road):
			return ""
		if st == "ice":
			return "얼음 위에는 길만 낼 수 있어요"
		return "용암 웅덩이예요" if st == "lava" else "연못이에요"
	return ""


## 포탑 설치 가능 여부. 가시 덫개 같은 함정은 길 칸에만 놓는다.
func can_build(c: Vector2i, towers: Dictionary, theme := 0, trap := false) -> String:
	if towers.has(c):
		return "이미 포탑이 있어요"
	if trap:
		if not in_bounds(c) or not is_path(c):
			return "함정은 길 칸에만 놓아요"
		return ""
	var err := ground_err(c, theme, false)
	if err != "":
		return err
	if is_path(c):
		return "길 위에는 지을 수 없어요"
	if theme >= 3 and GData.near_crack(c):
		return "용암 균열 옆에는 지을 수 없어요"
	return ""


## A(i)~B(j) 사이를 trail 칸들로 바꾼 새 경로 (trail 은 A·B 를 뺀 중간 칸)
func spliced(e: int, i: int, j: int, trail: Array) -> Array:
	var p: Array = paths[e]
	if i > j:
		var t := i
		i = j
		j = t
		trail = trail.duplicate()
		trail.reverse()
	var out: Array = p.slice(0, i + 1)
	out.append_array(trail)
	out.append_array(p.slice(j))
	return out


## 새 경로의 공사 자재 비용 (늘어난 칸 - 옛 도로 칸). 줄이면 음수 = 돌려받음
func cost_of(e: int, path: Array, theme: int) -> int:
	var old: Array = paths[e]
	var free := 0
	for c in path:
		if not old.has(c) and GData.is_old_road(c, theme):
			free += 1
	return path.size() - old.size() - free


## 기획서 유효 조건: 입구에서 시작, 본부까지 연결, 자기 교차 없음, 장애물·다른 길과 안 겹침.
## blockers: 포탑 칸 -> 주인 (함정은 넣지 않는다)
func validate(e: int, path: Array, blockers: Dictionary, theme: int, cap: int) -> String:
	if path.size() > cap:
		return "길이 상한(%d칸)을 넘어요" % cap
	if path.is_empty() or path[0] != paths[e][0]:
		return "입구와 이어지지 않아요"
	var seen := {}
	for idx in path.size():
		var c: Vector2i = path[idx]
		var err := ground_err(c, theme, true)
		if err != "" and not paths[e].has(c):
			return err
		if blockers.has(c):
			return "포탑과 겹쳐요"
		if seen.has(c):
			return "길이 자기 자신과 겹쳐요"
		seen[c] = true
		if idx > 0:
			var step: Vector2i = c - path[idx - 1]
			if absi(step.x) + absi(step.y) != 1:
				return "길이 끊겨요"
		for other in paths.size():
			if other != e and paths[other].has(c):
				return "다른 입구의 길과 겹쳐요"
	var last: Vector2i = path[path.size() - 1]
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_castle(last + d):
			return ""
	return "본부까지 이어지지 않아요"


## 봇·자동 감싸기용 후보: 곧은 구간을 ㄷ자(우회로) 또는 한쪽으로(굽잇길) 밀어낸 경로
const SHAPES := {"detour": [2, 2], "bend": [3, 1], "wide": [4, 2], "deep": [2, 3]}


func candidate(e: int, i: int, kind: String, side: int) -> Array:
	if e < 0 or e >= paths.size() or not SHAPES.has(kind) or absi(side) != 1:
		return []
	var p: Array = paths[e]
	var span: int = SHAPES[kind][0]
	var depth: int = SHAPES[kind][1]
	if i < 0 or i + span >= p.size():
		return []
	var a: Vector2i = p[i]
	var b: Vector2i = p[i + span]
	var dir: Vector2i = p[i + 1] - a
	for j in range(1, span + 1):
		if p[i + j] != a + dir * j:
			return []
	var n := Vector2i(-dir.y, dir.x) * side
	var trail: Array = []
	for k in range(1, depth + 1):
		trail.append(a + n * k)
	for j in range(1, span):
		trail.append(a + dir * j + n * depth)
	trail.append(b + n * depth)
	for k in range(depth - 1, 0, -1):
		trail.append(b + n * k)
	return spliced(e, i, i + span, trail)


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
		out.append(flat(p))
	return out


static func flat(p: Array) -> Array:
	var f := []
	for c in p:
		f.append(c.x)
		f.append(c.y)
	return f


static func unflat(f: Array) -> Array:
	var p: Array = []
	for k in range(0, f.size() - 1, 2):
		p.append(Vector2i(int(f[k]), int(f[k + 1])))
	return p


func load_data(d: Array) -> void:
	paths = []
	for f in d:
		paths.append(unflat(f))
