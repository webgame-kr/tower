class_name GData
extends RefCounted
## 규칙 수치와 맵 배치. 규칙 코드는 여기 값만 읽는다.
## 맵은 인원에 따라 두 가지다: 2인 21x13 (180° 회전 대칭), 3~4인 25x15 (상하·좌우 거울).

# ── 맵 (use_layout 으로 인원에 맞춰 바뀐다) ──
static var LAYOUT := "v2"
static var W := 21
static var H := 13
static var CASTLE := Rect2i(9, 5, 3, 3)
static var LANDMARK := Rect2i(9, 1, 3, 3)    # 고정 비건설 구역
static var BASE_PATHS: Array = []            # 처음부터 열린 길
static var EXTRA_PATH: Array = []            # 유령 숲에서 열리는 길
static var ROCKS: Array = []                 # Vector2i, 길·포탑 모두 불가
static var PONDS: Array = []                 # Rect2i, 테마마다 상태가 바뀜
static var BLOCKED := Rect2i()               # 막힌 땅 (유령 숲에서 열리는 길 자리)
static var POCKETS: Array = []               # 안쪽 포켓 (그리기 안내용)
static var WORKS: Array = []                 # 길 그리기 작업 공간 (안내용)
static var LINES: Array = []                 # 본부 앞 마지막 방어선 (안내용)
static var OLD_ROADS: Array = []             # 사막에서 드러나는 옛 도로 (자재 0)
static var CRACKS: Array = []                # 화산 균열 (용암 길)
static var SAND_SPOTS: Array = []            # 모래바람이 머물 수 있는 자리
static var CELL_PX := 36.0                   # 화면에서 한 칸 크기
static var ORIGIN := Vector2(262, 110)       # 화면에서 격자 시작점

const LAST_WAVE := 25         # 다섯 테마를 모두 지나는 구간
const THEME_LEN := 5
const CASTLE_HP := 100
const START_GOLD := 320
const REWARD_HEAL := 10
const REWARD_GOLD := 150
const REWARDS := {"heal": "본부 내구도 +10", "gold": "전원 +150G", "up": "전원 무료 강화 1회"}
const SELL_RATE := 0.8
const SLOW_CAP := 0.6
const ABILITY_RADIUS := 1.5
const ABILITY_TIME := 3.0
const ABILITY_SLOW := 0.4
const MAX_ALIVE := 70
const TICK := 0.05
const HP_GROWTH := 0.22

# ── 길 그리기와 공사 자재 ──
const MAT_START := 6
const MAT_WAVE := 3
const MAT_MAX := 12
const PATH_BASE := 40         # 입구별 길이 상한 (초원), 테마마다 +8
const PATH_STEP := 8
const KIT_SIZE := 5           # 공구함에 담는 포탑 수

static var hp_mul := 1.8      # 적 체력 배율 (밸런스 조정용)
static var budget_scale := {1: 0.85, 2: 0.85, 3: 1.06, 4: 1.28}
static var hp_scale := {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.15}


static func _cells(raw: Array) -> Array:
	var out: Array = []
	for c in raw:
		out.append(Vector2i(int(c[0]), int(c[1])))
	return out


## 인원에 맞는 맵을 고른다. 판정·그리기 모두 이 값을 쓴다.
static func use_layout(players: int) -> void:
	if players >= 3:
		LAYOUT = "v4"
		W = 25
		H = 15
		CASTLE = Rect2i(11, 6, 3, 3)
		LANDMARK = Rect2i(11, 0, 3, 3)
		CELL_PX = 30.0
		ORIGIN = Vector2(265, 115)
		var p1 := _cells([[0, 1], [1, 1], [2, 1], [3, 1], [3, 2], [3, 3], [3, 4], [3, 5], [4, 5], [5, 5], [6, 5], [7, 5], [7, 4], [7, 3], [7, 2], [7, 1], [8, 1], [9, 1], [10, 1], [10, 2], [10, 3], [10, 4], [11, 4], [11, 5]])
		var quad := [[], [], [], []]
		for c in p1:
			quad[0].append(c)
			quad[1].append(Vector2i(24 - c.x, c.y))
			quad[2].append(Vector2i(c.x, 14 - c.y))
			quad[3].append(Vector2i(24 - c.x, 14 - c.y))
		BASE_PATHS = [quad[0], quad[1], quad[2]] if players == 3 else quad
		EXTRA_PATH = quad[3] if players == 3 else _cells([[12, 14], [12, 13], [11, 13], [11, 12], [11, 11], [12, 11], [12, 10], [12, 9]])
		ROCKS = _cells([[5, 7], [19, 7], [8, 0], [9, 0], [15, 0], [16, 0], [8, 14], [9, 14], [15, 14], [16, 14]])
		PONDS = [Rect2i(1, 6, 3, 3), Rect2i(21, 6, 3, 3)]
		BLOCKED = Rect2i(11, 11, 3, 4)
		POCKETS = [Rect2i(4, 1, 3, 4), Rect2i(18, 1, 3, 4), Rect2i(4, 10, 3, 4), Rect2i(18, 10, 3, 4)]
		WORKS = [Rect2i(0, 2, 3, 4), Rect2i(22, 2, 3, 4), Rect2i(0, 9, 3, 4), Rect2i(22, 9, 3, 4)]
		LINES = [Rect2i(10, 6, 1, 3), Rect2i(14, 6, 1, 3)]
		OLD_ROADS = [Rect2i(6, 7, 4, 1), Rect2i(15, 7, 4, 1)]
		CRACKS = _cells([[7, 2], [7, 3], [17, 2], [17, 3], [7, 11], [7, 12], [17, 11], [17, 12]])
		SAND_SPOTS = [Vector2(5.5, 3.0), Vector2(19.5, 3.0), Vector2(5.5, 12.0), Vector2(19.5, 12.0), Vector2(8.5, 7.5), Vector2(16.5, 7.5)]
	else:
		LAYOUT = "v2"
		W = 21
		H = 13
		CASTLE = Rect2i(9, 5, 3, 3)
		LANDMARK = Rect2i(9, 1, 3, 3)
		CELL_PX = 36.0
		ORIGIN = Vector2(262, 110)
		var a := _cells([[0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [5, 2], [5, 3], [5, 4], [4, 4], [3, 4], [2, 4], [2, 5], [2, 6], [2, 7], [2, 8], [2, 9], [3, 9], [4, 9], [5, 9], [6, 9], [7, 9], [7, 8], [7, 7], [7, 6], [8, 6]])
		var b: Array = []
		for c in a:
			b.append(Vector2i(20 - c.x, 12 - c.y))
		BASE_PATHS = [a, b]
		EXTRA_PATH = _cells([[10, 12], [10, 11], [11, 11], [12, 11], [12, 10], [12, 9], [11, 9], [10, 9], [9, 9], [9, 8]])
		ROCKS = _cells([[6, 2], [6, 3], [14, 9], [14, 10], [0, 6], [0, 7], [20, 5], [20, 6], [15, 0], [16, 0], [15, 1], [5, 12], [4, 12], [5, 11]])
		PONDS = [Rect2i(12, 0, 3, 3), Rect2i(6, 10, 3, 3)]
		BLOCKED = Rect2i(9, 9, 4, 4)
		POCKETS = [Rect2i(3, 5, 4, 4), Rect2i(14, 4, 4, 4)]
		WORKS = [Rect2i(0, 10, 4, 3), Rect2i(17, 0, 4, 3)]
		LINES = [Rect2i(8, 5, 1, 3), Rect2i(12, 5, 1, 3)]
		OLD_ROADS = [Rect2i(1, 11, 4, 1), Rect2i(16, 1, 4, 1)]
		CRACKS = _cells([[2, 6], [2, 7], [18, 6], [18, 5]])
		SAND_SPOTS = [Vector2(4.5, 6.5), Vector2(16.5, 6.0), Vector2(4.0, 2.5), Vector2(17.0, 10.5), Vector2(10.5, 4.0), Vector2(10.5, 9.0)]


## 처음 열린 입구 수
static func lanes_for(players: int) -> int:
	return clampi(players, 2, 4)


static func theme_of(wave: int) -> int:
	return clampi((wave - 1) / THEME_LEN, 0, THEMES.size() - 1)


## 입구별 길이 상한
static func max_path(wave: int) -> int:
	return PATH_BASE + PATH_STEP * theme_of(wave)


## 연못 상태: 물(길·포탑 불가) · 얼음(길 가능, 빙판) · 마른 땅(모두 가능) · 용암(불가)
static func pond_state(theme: int) -> String:
	return ["water", "ice", "dry", "lava", "water"][clampi(theme, 0, 4)]


static func in_rects(c: Vector2i, rects: Array) -> bool:
	for r in rects:
		if (r as Rect2i).has_point(c):
			return true
	return false


static func is_pond(c: Vector2i) -> bool:
	return in_rects(c, PONDS)


static func is_old_road(c: Vector2i, theme: int) -> bool:
	return theme >= 2 and in_rects(c, OLD_ROADS)


## 용암 균열 옆 칸 (화산부터 포탑 금지)
static func near_crack(c: Vector2i) -> bool:
	for k in CRACKS:
		if absi(k.x - c.x) <= 1 and absi(k.y - c.y) <= 1 and k != c:
			return true
	return false


const THEMES := [
	{"id": "grass", "name": "초원", "desc": "길 그리기와 포켓 활용 배우기", "landmark": "굴착기", "zone": "", "wipe": "#3F5B31", "road": [["#5A4A36", 0.9, 0, 1], ["#A8936C", 0.76, 0, 1], ["#8C7A58", 0.5, 0, 0.9], ["#A8936C", 0.36, 0, 1]]},
	{"id": "snow", "name": "설원", "desc": "연못이 얼어 그 위로 길을 낼 수 있어요 · 얼음 길은 빙판", "landmark": "얼어붙은 시추기", "zone": "ice", "wipe": "#DCE8EE", "road": [["#FFFFFF", 1.08, 0, 0.95], ["#C9D6DC", 0.98, 1, 1], ["#68747B", 0.9, 0, 1], ["#8B979E", 0.76, 0, 1], ["#7A868D", 0.5, 0, 0.9], ["#8B979E", 0.36, 0, 1]]},
	{"id": "sand", "name": "사막", "desc": "옛 도로 칸은 자재 0 · 모래바람 구역은 포탑 사거리 감소", "landmark": "모래에 잠긴 수송차", "zone": "sand", "wipe": "#C9A566", "road": [["#CDAE74", 1, 1, 0.9], ["#4C4844", 0.9, 0, 1], ["#9A958C", 0.76, 0, 1], ["#D9C9A6", 0.05, 1, 0.6]]},
	{"id": "lava", "name": "화산", "desc": "균열을 지나는 적은 지속 피해 · 균열 옆에는 포탑 금지", "landmark": "파손된 용광로", "zone": "lava", "wipe": "#7A2412", "road": [["#211D1B", 0.9, 0, 1], ["#8A827B", 0.76, 0, 1], ["#6E6862", 0.76, 1, 1], ["#000000", 0.3, 0, 0.18]]},
	{"id": "ghost", "name": "유령 숲", "desc": "막힌 땅이 열리며 새 입구가 생겨요", "landmark": "거목 급수탑", "zone": "ghost", "wipe": "#2B3F36", "road": [["#4E7A55", 1.02, 1, 0.9], ["#2C312C", 0.9, 0, 1], ["#8E948C", 0.76, 0, 1], ["#7C827A", 0.76, 1, 1]]},
]

const ICE_SPEED := 1.3
const SAND_RADIUS := 2.6
const SAND_RANGE := 0.75
const LAVA_RATE := 0.05       # 초당 최대 체력 비율

const PING_KINDS := {
	"look": "주목", "danger": "위험!", "build": "건설 요청", "road": "길 변경 제안", "mine": "여긴 내가 맡을게",
}

# ── 포탑 10종 ──
## 값: dmg 피해, cd 간격, range 사거리, splash 폭발, slow 감속, aura 범위 전체, line 관통선, shred 방어 감소,
## oil 기름 시간, fire 불(기름 ×3), chain 연쇄 수, jump 튀는 거리, buff 주변 사거리, reveal 유령 실체화,
## mark 받는 피해 증가, trap 길 위 함정, uses 내구
const TOWERS := {
	"gun": {
		"name": "기관포탑", "role": "단일 연사", "cost": 100, "up": [80, 120], "art": 0,
		"lv": [{"dmg": 5.0, "cd": 0.3, "range": 3.0}, {"dmg": 8.0, "cd": 0.3, "range": 3.0}],
		"a": {"label": "회전 4연장", "dmg": 8.0, "cd": 0.15, "range": 3.0},
		"b": {"label": "관통 장포신", "dmg": 18.0, "cd": 0.45, "range": 3.6, "pierce": 6.0, "line": true},
	},
	"cannon": {
		"name": "대포탑", "role": "범위 폭발", "cost": 150, "up": [120, 180], "art": 1,
		"lv": [{"dmg": 16.0, "cd": 1.6, "range": 2.5, "splash": 1.0}, {"dmg": 24.0, "cd": 1.6, "range": 2.5, "splash": 1.0}],
		"a": {"label": "폭발 범위 확대", "dmg": 24.0, "cd": 1.6, "range": 2.5, "splash": 1.6},
		"b": {"label": "좁은 범위 고피해", "dmg": 52.0, "cd": 1.6, "range": 2.5, "splash": 1.0},
	},
	"cold": {
		"name": "냉각탑", "role": "범위 감속", "cost": 120, "up": [100, 140], "art": 2,
		"lv": [{"dmg": 1.0, "cd": 1.0, "range": 2.0, "slow": 0.3, "aura": true}, {"dmg": 2.0, "cd": 0.8, "range": 2.0, "slow": 0.3, "aura": true}],
		"a": {"label": "냉기 장막", "dmg": 2.0, "cd": 0.8, "range": 3.0, "slow": 0.3, "aura": true},
		"b": {"label": "얼음 송곳", "dmg": 6.0, "cd": 0.8, "range": 2.0, "slow": 0.55},
	},
	"magnet": {
		"name": "자석탑", "role": "방어력 감소", "cost": 140, "up": [110, 150], "art": 5,
		"lv": [{"dmg": 2.0, "cd": 0.8, "range": 2.5, "shred": 0.4}, {"dmg": 3.0, "cd": 0.6, "range": 2.5, "shred": 0.5}],
		"a": {"label": "자기장", "dmg": 2.0, "cd": 0.8, "range": 2.5, "shred": 0.4, "aura": true},
		"b": {"label": "갑옷 분쇄", "dmg": 8.0, "cd": 0.6, "range": 2.5, "shred": 0.7},
	},
	"oil": {
		"name": "기름분사탑", "role": "기름 상태 부여", "cost": 110, "up": [90, 130], "art": 3,
		"lv": [{"dmg": 1.0, "cd": 1.0, "range": 2.0, "splash": 0.8, "oil": 4.0}, {"dmg": 1.0, "cd": 0.8, "range": 2.0, "splash": 1.0, "oil": 6.0}],
		"a": {"label": "점착 기름", "dmg": 1.0, "cd": 0.8, "range": 2.0, "splash": 1.0, "oil": 6.0, "slow": 0.25},
		"b": {"label": "고압 분사", "dmg": 1.0, "cd": 0.6, "range": 2.6, "splash": 1.4, "oil": 6.0},
	},
	"flame": {
		"name": "불꽃탑", "role": "근거리 지속 피해", "cost": 130, "up": [100, 150], "art": 4,
		"lv": [{"dmg": 3.0, "cd": 0.25, "range": 1.5, "aura": true, "fire": true}, {"dmg": 4.5, "cd": 0.25, "range": 1.5, "aura": true, "fire": true}],
		"a": {"label": "화염 확산", "dmg": 4.5, "cd": 0.25, "range": 2.2, "aura": true, "fire": true},
		"b": {"label": "고열 노즐", "dmg": 8.0, "cd": 0.25, "range": 1.5, "aura": true, "fire": true},
	},
	"shock": {
		"name": "전기탑", "role": "연쇄 번개", "cost": 160, "up": [130, 170], "art": 6,
		"lv": [{"dmg": 10.0, "cd": 1.2, "range": 2.5, "chain": 4, "jump": 1.5}, {"dmg": 14.0, "cd": 1.2, "range": 2.5, "chain": 4, "jump": 1.5}],
		"a": {"label": "연쇄 증폭", "dmg": 14.0, "cd": 1.2, "range": 2.5, "chain": 6, "jump": 1.8},
		"b": {"label": "고압 방전", "dmg": 24.0, "cd": 1.2, "range": 2.5, "chain": 3, "jump": 1.5},
	},
	"sniper": {
		"name": "저격탑", "role": "아주 먼 단발", "cost": 170, "up": [140, 180], "art": 7,
		"lv": [{"dmg": 60.0, "cd": 2.5, "range": 6.0}, {"dmg": 85.0, "cd": 2.5, "range": 6.0}],
		"a": {"label": "대구경", "dmg": 150.0, "cd": 3.0, "range": 6.5, "pierce": 6.0},
		"b": {"label": "속사 조준경", "dmg": 70.0, "cd": 1.4, "range": 6.0},
	},
	"signal": {
		"name": "신호탑", "role": "보조", "cost": 120, "up": [100, 130], "art": 8,
		"lv": [{"range": 2.0, "buff": 0.15, "reveal": true, "support": true}, {"range": 2.0, "buff": 0.2, "reveal": true, "support": true}],
		"a": {"label": "증폭 안테나", "range": 3.0, "buff": 0.25, "reveal": true, "support": true},
		"b": {"label": "표적 지정", "range": 2.0, "buff": 0.2, "reveal": true, "support": true, "mark": 0.15},
	},
	"spike": {
		"name": "가시 덫개", "role": "길 위 함정", "cost": 60, "up": [50, 80], "art": 9,
		"lv": [{"dmg": 20.0, "range": 0.5, "trap": true, "uses": 30}, {"dmg": 30.0, "range": 0.5, "trap": true, "uses": 40}],
		"a": {"label": "점착 장판", "dmg": 10.0, "range": 0.5, "trap": true, "uses": 60, "slow": 0.4},
		"b": {"label": "대형 가시", "dmg": 50.0, "range": 0.5, "trap": true, "uses": 40},
	},
}
const TOWER_ORDER := ["gun", "cannon", "cold", "magnet", "oil", "flame", "shock", "sniper", "signal", "spike"]
const DEFAULT_KIT := ["gun", "cannon", "cold", "magnet", "spike"]
const TRAP_REPAIR := 1        # 가시 덫개 수리에 드는 공사 자재

# ── 적 ──
## heal 초당 회복(heal_r 칸 안), ice 빙판 위 속도 배율, slow_res 감속 저항, burrow [주기, 땅속 시간],
## guard 주변 적 보호막, fireproof 불·용암 면역, split [작은 적, 수], phase [주기, 조준 불가 시간],
## trail 지나간 칸 빙판(초), drops [체력 비율들, 적, 수], overheat [주기, 반경, 시간], clone 분신 체력 비율
const ENEMIES := {
	"grunt": {"name": "일반병", "hp": 34.0, "armor": 0.0, "speed": 1.25, "hit": 1, "price": 1.0, "look": [0, ""]},
	"swarm": {"name": "떼거리", "hp": 13.0, "armor": 0.0, "speed": 1.6, "hit": 1, "price": 0.5, "look": [1, ""]},
	"heavy": {"name": "중장갑", "hp": 120.0, "armor": 4.0, "speed": 0.8, "hit": 1, "price": 4.0, "look": [2, ""]},
	"rusher": {"name": "돌격병", "hp": 42.0, "armor": 0.0, "speed": 2.4, "hit": 1, "price": 1.5, "look": [3, ""]},
	"healer": {"name": "치유사", "hp": 50.0, "armor": 0.0, "speed": 1.1, "hit": 1, "price": 3.0, "heal": 5.0, "heal_r": 2.0, "look": [0, "#64D4A3"]},
	"sled": {"name": "썰매병", "hp": 40.0, "armor": 0.0, "speed": 1.5, "hit": 1, "price": 2.0, "ice": 2.0, "look": [3, "#BFE3F2"]},
	"shield": {"name": "방패병", "hp": 70.0, "armor": 2.0, "speed": 1.0, "hit": 1, "price": 3.0, "slow_res": 0.5, "look": [2, "#9CB4C8"]},
	"worm": {"name": "굴착 벌레", "hp": 60.0, "armor": 0.0, "speed": 1.2, "hit": 1, "price": 3.0, "burrow": [3.0, 1.5], "look": [1, "#C9A566"]},
	"carrier": {"name": "방패 수송차", "hp": 150.0, "armor": 2.0, "speed": 0.7, "hit": 1, "price": 5.0, "guard": 30.0, "look": [2, "#E9B935"]},
	"golem": {"name": "내열 골렘", "hp": 160.0, "armor": 6.0, "speed": 0.75, "hit": 1, "price": 5.0, "fireproof": true, "look": [2, "#F47A3A"]},
	"splitter": {"name": "분열체", "hp": 80.0, "armor": 0.0, "speed": 1.0, "hit": 1, "price": 3.0, "split": ["mini", 2], "look": [0, "#E0533D"]},
	"mini": {"name": "작은 분열체", "hp": 25.0, "armor": 0.0, "speed": 1.6, "hit": 1, "price": 0.0, "look": [1, "#E0533D"]},
	"phantom": {"name": "유령병", "hp": 55.0, "armor": 0.0, "speed": 1.2, "hit": 1, "price": 3.0, "phase": [5.0, 2.0], "look": [3, "#8FD9B6"]},
	"vine": {"name": "덩굴 치유사", "hp": 70.0, "armor": 0.0, "speed": 1.0, "hit": 1, "price": 4.0, "heal": 4.0, "heal_r": 2.0, "slow_res": 1.0, "look": [0, "#4E7A55"]},
	"boss": {"name": "초원 대장", "hp": 380.0, "armor": 3.0, "speed": 0.62, "hit": 15, "price": 0.0, "boss": true, "look": [4, ""], "skill": ""},
	"walker": {"name": "쇄빙 보행기", "hp": 470.0, "armor": 3.0, "speed": 0.6, "hit": 15, "price": 0.0, "boss": true, "trail": 5.0, "look": [4, "#BFE3F2"], "skill": "지나간 길을 5초 동안 빙판으로"},
	"fortress": {"name": "모래 수송 요새", "hp": 560.0, "armor": 4.0, "speed": 0.5, "hit": 15, "price": 0.0, "boss": true, "drops": [[0.5, 0.0], "swarm", 8], "look": [4, "#E9B935"], "skill": "체력 50%·0%에서 떼거리 8명"},
	"giant": {"name": "용광로 거인", "hp": 640.0, "armor": 5.0, "speed": 0.55, "hit": 15, "price": 0.0, "boss": true, "overheat": [8.0, 2.0, 2.0], "fireproof": true, "look": [4, "#F47A3A"], "skill": "8초마다 주변 포탑 과열"},
	"shadow": {"name": "그림자 사령관", "hp": 720.0, "armor": 3.0, "speed": 0.65, "hit": 15, "price": 0.0, "boss": true, "clone": 0.5, "look": [4, "#8FD9B6"], "skill": "체력 50%에서 분신 소환"},
}
## 테마별 전용 적과 보스 (전용 적은 앞 테마에서 통하던 전략을 하나씩 막는다)
const THEME_FOES := [["healer"], ["sled", "shield"], ["worm", "carrier"], ["golem", "splitter"], ["phantom", "vine"]]
const THEME_BOSS := ["boss", "walker", "fortress", "giant", "shadow"]
const GAPS := {"grunt": 0.9, "swarm": 0.4, "heavy": 2.6, "rusher": 0.7}


static func is_boss(type: String) -> bool:
	return bool(ENEMIES[type].get("boss", false))


static func wave_gold(wave: int) -> int:
	return 120 + wave * 20


## 일찍 부르기: 적이 다 나온 뒤 남은 적이 많을수록 보너스가 크다 (위험을 감수한 만큼)
const EARLY_PER_ENEMY := 6
const EARLY_MIN := 30
const EARLY_MAX := 120


static func early_bonus(alive: int) -> int:
	return clampi(alive * EARLY_PER_ENEMY, EARLY_MIN, EARLY_MAX)


static func wave_budget(wave: int, players: int) -> float:
	return (20.0 + wave * 6.0) * float(budget_scale.get(clampi(players, 1, 4), 1.0))


static func wave_hp(wave: int, players := 2) -> float:
	return (1.0 + maxi(wave - 6, 0) * HP_GROWTH) * float(hp_scale.get(clampi(players, 1, 4), 1.0))


## 위협 예산으로 웨이브를 만든다. 결과: [입구, 적, 수, 간격(초), 시작(초)] 묶음들.
## weak: 직전 웨이브에 본부 피해를 가장 적게 받은 입구 (조금 더 보낸다)
static func make_wave(wave: int, players: int, lanes: int, seed_: int, weak := -1) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_, wave, lanes])
	var budget := wave_budget(wave, players)
	var theme := theme_of(wave)
	var k := (wave - 1) % THEME_LEN + 1
	var foes: Array = THEME_FOES[theme]
	var commons := ["grunt"]
	if wave >= 2:
		commons.append("swarm")
	if wave >= 4:
		commons.append("heavy")
	if wave >= 6:
		commons.append("rusher")
	var groups: Array = []
	# 입구 배분
	var weights: Array = []
	var splits := [[0.6, 0.4], [0.5, 0.5], [0.8, 0.2]]
	if lanes == 2:
		var sp: Array = splits[rng.randi_range(0, 2)]
		weights = [sp[0], sp[1]] if rng.randf() < 0.5 else [sp[1], sp[0]]
	else:
		for _i in lanes:
			weights.append(0.6 + rng.randf() * 0.8)
	if weak >= 0 and weak < lanes:
		weights[weak] = float(weights[weak]) + 0.2
	var total_w := 0.0
	for w in weights:
		total_w += float(w)
	var t0 := 0.0
	if k == THEME_LEN:
		var lane := rng.randi_range(0, lanes - 1)
		groups.append([lane, THEME_BOSS[theme], 1, 0.0, 3.0])
		budget *= 0.5
	var special := 0.0
	var special_types: Array = []
	if k == 1:
		special = 0.4
		special_types = [foes[0]]
	elif k == 2:
		special = 0.35
		special_types = [foes[foes.size() - 1]]
	else:
		special = 0.35
		special_types = foes
	# 전용 적: 테마 첫 웨이브는 입구 하나에만
	var sp_budget := budget * special
	var sp_lane := rng.randi_range(0, lanes - 1)
	for i in special_types.size():
		var type: String = special_types[i]
		var share := sp_budget / special_types.size()
		var n := maxi(1, int(share / float(ENEMIES[type]["price"])))
		var lane := sp_lane if k == 1 else (sp_lane + i) % lanes
		groups.append([lane, type, n, 1.4, 2.0 + i * 2.0])
	# 공통 적
	var rest := budget - sp_budget
	for e in lanes:
		var lane_budget := rest * float(weights[e]) / total_w
		var counts := {}
		var guard := 0
		while lane_budget > 0.4 and guard < 400:
			guard += 1
			var type: String = commons[rng.randi_range(0, commons.size() - 1)]
			var price: float = ENEMIES[type]["price"]
			if price > lane_budget:
				type = "swarm" if commons.has("swarm") else "grunt"
				price = ENEMIES[type]["price"]
				if price > lane_budget:
					break
			counts[type] = int(counts.get(type, 0)) + 1
			lane_budget -= price
		t0 = 0.0
		for type in ["grunt", "swarm", "rusher", "heavy"]:
			if counts.has(type):
				var n: int = counts[type]
				groups.append([e, type, n, GAPS[type], t0])
				t0 += n * float(GAPS[type]) * 0.4
	return groups


## 지금 단계의 포탑 능력치
static func tower_stats(type: String, level: int, branch: String) -> Dictionary:
	var d: Dictionary = TOWERS[type]
	var s: Dictionary
	if level >= 3 and branch != "":
		s = d[branch]
	else:
		s = d["lv"][clampi(level - 1, 0, 1)]
	return {
		"dmg": float(s.get("dmg", 0.0)), "cd": float(s.get("cd", 1.0)), "range": float(s.get("range", 3.0)),
		"splash": float(s.get("splash", 0.0)), "slow": float(s.get("slow", 0.0)), "pierce": float(s.get("pierce", 0.0)),
		"aura": bool(s.get("aura", false)), "line": bool(s.get("line", false)), "shred": float(s.get("shred", 0.0)),
		"oil": float(s.get("oil", 0.0)), "fire": bool(s.get("fire", false)), "chain": int(s.get("chain", 0)),
		"jump": float(s.get("jump", 0.0)), "buff": float(s.get("buff", 0.0)), "reveal": bool(s.get("reveal", false)),
		"mark": float(s.get("mark", 0.0)), "trap": bool(s.get("trap", false)), "uses": int(s.get("uses", 0)),
		"support": bool(s.get("support", false)),
	}


static func _static_init() -> void:
	use_layout(2)
