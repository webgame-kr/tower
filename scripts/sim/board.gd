class_name Board
extends RefCounted
## 격자와 적 경로. 길 다시 그리기와 설치 유효성 검사를 맡는다.

var paths: Array = []   # 입구별 Array[Vector2i]
var opened := false     # 새 입구가 하나라도 열렸는지
var extra := 0          # 열린 새 입구 수 (테마마다 하나)


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
	if GData.is_river(c):
		if GData.is_bridge(c):
			return "" if for_road else "다리 위에는 길만 낼 수 있어요"
		return "강이에요"
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


## 합류: e 의 i 칸에서 trail 을 지나 f 의 j 칸으로 들어가 그 뒤를 함께 쓴다
func merged(e: int, i: int, trail: Array, f: int, j: int) -> Array:
	var out: Array = paths[e].slice(0, i + 1)
	out.append_array(trail)
	out.append_array(paths[f].slice(j))
	return out


## e 를 path 로 바꿀 때 e 와 합류해 있던 길들이 따라 바뀐 모습 (합류 지점이 남아 있을 때만)
func synced(e: int, path: Array) -> Dictionary:
	var out := {}
	var old: Array = paths[e]
	for o in paths.size():
		if o == e:
			continue
		var p: Array = paths[o]
		var k := merge_index(p, old)
		if k < 0:
			continue
		var jn := path.find(p[k])
		if jn < 0:
			continue      # 갈라졌다: 그 길은 그대로
		var np: Array = p.slice(0, k)
		np.append_array(path.slice(jn))
		if np != p:
			out[o] = np
	return out


## p 가 o 에 합류하는 첫 칸 (그 칸부터 본부까지 o 와 같은 길). 없으면 -1
static func merge_index(p: Array, o: Array) -> int:
	if p.is_empty() or o.is_empty() or p[p.size() - 1] != o[o.size() - 1]:
		return -1      # 끝(본부 앞 칸)이 다르면 합류가 아니다
	var k := p.size() - 1
	var j := o.size() - 1
	while k > 0 and j > 0 and p[k - 1] == o[j - 1]:
		k -= 1
		j -= 1
	return k


## 두 길이 합류한 칸 목록 [칸, 길 a, 길 b] (a 가 b 에 합류하거나 그 반대)
func junctions() -> Array:
	var out := []
	for a in paths.size():
		for b in range(a + 1, paths.size()):
			var k := merge_index(paths[a], paths[b])
			if k >= 0:
				out.append([paths[a][k], a, b])
	return out


## 교차로 목록 [칸, 길 a, 길 b]: 두 길이 한 칸만 공유하고 가로질러 지나간다
static func crossings_of(all: Array) -> Array:
	var out := []
	var sets := []
	for p in all:
		var d := {}
		for c in p:
			d[c] = true
		sets.append(d)
	for a in all.size():
		for b in range(a + 1, all.size()):
			var pa: Array = all[a]
			var pb: Array = all[b]
			var shared := []
			for c in pa:
				if (sets[b] as Dictionary).has(c):
					shared.append(c)
			if shared.is_empty():
				continue
			var tail := {}
			var ka := merge_index(pa, pb)
			if ka >= 0:
				for c in pa.slice(ka):
					tail[c] = true
			for c in shared:
				if not tail.has(c):
					out.append([c, a, b])
	return out


func crossings() -> Array:
	return crossings_of(paths)


## 합류한 공동 구간 칸 (두 길 이상이 본부까지 함께 쓰는 칸)
func shared_cells() -> Dictionary:
	var out := {}
	for jn in junctions():
		var p: Array = paths[int(jn[1])]
		for c in p.slice(p.find(jn[0])):
			out[c] = true
	return out


## 길 하나에 있는 교차로 수
static func cross_count(all: Array, e: int) -> int:
	var n := 0
	for x in crossings_of(all):
		if int(x[1]) == e or int(x[2]) == e:
			n += 1
	return n


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
## lanes: 다른 길들의 상태 (합류로 함께 바뀌는 길을 반영할 때)
func validate(e: int, path: Array, blockers: Dictionary, theme: int, cap: int, lanes: Array = []) -> String:
	var all: Array = lanes if not lanes.is_empty() else paths
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
	var lanes2: Array = all.duplicate()
	lanes2[e] = path
	for other in all.size():      # 다른 길과 겹치면 합류(본부까지 같은 길) 아니면 교차(한 칸만 가로질러)
		if other == e:
			continue
		var o: Array = all[other]
		var km := merge_index(path, o)
		var end := km if km >= 0 else path.size()
		for k in end:
			if not o.has(path[k]):
				continue
			var err := _cross_err(path, k, o)
			if err != "":
				return err
	var xs := crossings_of(lanes2)
	if not xs.is_empty():
		var per := {}
		for x in xs:
			per[x[1]] = int(per.get(x[1], 0)) + 1
			per[x[2]] = int(per.get(x[2], 0)) + 1
		for l in per:
			if int(per[l]) > CROSS_MAX:
				return "교차로는 길마다 %d곳까지예요" % CROSS_MAX
	var last: Vector2i = path[path.size() - 1]
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_castle(last + d):
			return ""
	return "본부까지 이어지지 않아요"


const CROSS_MAX := 2


## path 의 k 칸이 o 와 겹칠 때: 앞뒤 칸은 겹치지 않고 서로 직각으로 곧게 지나가야 교차로
static func _cross_err(path: Array, k: int, o: Array) -> String:
	var j := o.find(path[k])
	if k == 0 or k == path.size() - 1 or j <= 0 or j == o.size() - 1:
		return "다른 길과 겹쳐요 · 합류하면 본부까지 같은 길이어야 해요"
	if o.has(path[k - 1]) or o.has(path[k + 1]):
		return "다른 길과 겹쳐요 · 합류하면 본부까지 같은 길이어야 해요"
	var d1: Vector2i = path[k + 1] - path[k - 1]
	var d2: Vector2i = o[j + 1] - o[j - 1]
	if absi(d1.x) + absi(d1.y) != 2 or absi(d2.x) + absi(d2.y) != 2 or d1.x * d2.x + d1.y * d2.y != 0 or (d1.x != 0 and d1.y != 0) or (d2.x != 0 and d2.y != 0):
		return "교차로는 두 길이 곧게 가로질러야 해요"
	return ""


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
