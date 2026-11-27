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
static var EXTRA_PATH: Array = []            # 첫 번째로 열리는 길 (예전 이름)
static var EXTRA_PATHS: Array = []           # 테마가 바뀔 때마다 하나씩 열리는 길
static var RIVERS: Array = []                # Rect2i, 강: 길·포탑 불가 (다리만 길)
static var BRIDGES: Array = []               # Rect2i, 다리: 길만 낼 수 있다
static var HIGH: Array = []                  # Rect2i, 높은 땅: 사거리 +1칸
static var ART_ORIGIN := Vector2.ZERO        # 지도 그림에서 격자 시작점 (원본 px)
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
static var ORIGIN := Vector2(220, 112)       # 화면에서 격자 시작점

const LAST_WAVE := 25         # 다섯 테마를 모두 지나는 구간
const THEME_LEN := 5
const CASTLE_HP := 100
const START_GOLD := 320
static var start_gold_override := 0
const REWARD_HEAL := 10
const LEAK_FREE := 2          # 웨이브마다 처음 새는 적 2마리는 본부 방벽이 막는다 (피해 0)
const HQ_WAVE_CAP := 50       # 한 웨이브에 본부가 잃는 내구도 상한 (한 번에 무너지지 않게)
const REWARD_GOLD := 150
const REWARDS := {"heal": "본부 내구도 +10", "gold": "전원 +150G", "up": "전원 무료 강화 1회"}
const SELL_RATE := 0.8
const SLOW_CAP := 0.6
const ABILITY_RADIUS := 1.5
const ABILITY_TIME := 3.0
const ABILITY_SLOW := 0.4
const MAX_ALIVE := 70
const TICK := 0.05
const HP_GROWTH := 0.25
const ENDLESS_HP := 1.04       # 25웨이브 뒤 웨이브마다 적 체력 ×1.04 (선형 증가 위에 곱)

# ── 길 그리기와 공사 자재 ──
const MAT_START := 6
const MAT_WAVE := 3
const MAT_MAX := 12
static var PATH_BASE := 70    # 입구별 길이 상한 (초원), 테마마다 +8 · 맵마다 다르다 (use_layout)
const PATH_STEP := 8
const KIT_SIZE := 4           # 이번 테마 공구함 (테마가 바뀔 때 카드에서 고른다)
const HAND_SIZE := 6          # 준비 시작 때 나오는 카드 수
const REROLL_COST := 30       # 다시 뽑기 (테마마다 첫 번은 무료)
const TEAM_KIT_BONUS := 6     # 팀 공구함이 서로 다른 n종 이상이면 공사 자재 +1

static var hp_mul := 6.6      # 적 체력 배율 (밸런스 조정용)
static var budget_scale := {1: 0.75, 2: 0.75, 3: 0.92, 4: 0.78}
static var hp_scale := {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.05}
const DIFFICULTY := {"easy": [0.8, 0.85, "느긋"], "normal": [1.0, 1.0, "보통"], "hard": [1.25, 1.15, "빡빡"]}      # [적 체력, 위협 예산]
static var difficulty := "normal"


static func _cells(raw: Array) -> Array:
	var out: Array = []
	for c in raw:
		out.append(Vector2i(int(c[0]), int(c[1])))
	return out


## 인원에 맞는 맵을 고른다. 판정·그리기 모두 이 값을 쓴다 (배치는 tools/make_maps.py → MapData).
static func use_layout(players: int) -> void:
	LAYOUT = "v2" if players <= 2 else ("v3" if players == 3 else "v4")
	var L: Dictionary = MapData.get_layout(LAYOUT)
	W = int(L["W"])
	H = int(L["H"])
	CASTLE = L["castle"]
	PATH_BASE = 70 if LAYOUT == "v2" else 86
	LANDMARK = L["landmark"]
	BASE_PATHS = L["base"]
	EXTRA_PATHS = L["extra"]
	EXTRA_PATH = EXTRA_PATHS[0] if not EXTRA_PATHS.is_empty() else []
	ROCKS = L["rocks"]
	PONDS = L["ponds"]
	RIVERS = L["rivers"]
	BRIDGES = L["bridges"]
	HIGH = L["high"]
	BLOCKED = Rect2i()
	OLD_ROADS = L["old_roads"]
	CRACKS = L["cracks"]
	SAND_SPOTS = L["sand"]
	POCKETS = []
	WORKS = []
	LINES = []
	CELL_PX = 38.0
	ORIGIN = Vector2(0, 0)
	ART_ORIGIN = Vector2(MapData.ART_MARGIN) * 19.0


## 처음 열린 입구 수
static func lanes_for(players: int) -> int:
	return clampi(players, 2, 4)


## 몇 번째 테마 구간인가 (0부터). 난이도·포탑 해금·길 길이는 이 값을 따른다
static func stage_of(wave: int) -> int:
	return maxi((wave - 1) / THEME_LEN, 0)


## 이 웨이브의 테마 (THEMES 번호). 판마다 ORDER 로 순서가 섞인다
static var ORDER: Array = [0, 1, 2, 3, 4]
static var endless_mode := false      # 대기실에서 고른 무한 모드 (25웨이브에서 끝나지 않음)
const POOL_A := [1, 2, 5]             # 2·3번째 테마 후보: 설원 · 사막 · 늪 정제소
const POOL_B := [3, 4, 6, 7]          # 4·5번째 테마 후보: 화산 · 유령 숲 · 폭풍 고원 · 고철 처리장


static func theme_of(wave: int) -> int:
	var st := stage_of(wave)
	if st < ORDER.size():
		return int(ORDER[st])
	var tail: Array = ORDER.slice(1)      # 무한: 초원을 뺀 테마를 계속 돈다
	return int(tail[(st - ORDER.size()) % tail.size()])


## 판마다 테마 순서: 초원 → A 묶음 2개 → B 묶음 2개 (무한 모드는 남은 테마까지 이어서)
static var fixed_order := false      # 테스트용: 섞지 않음


static func make_order(seed_: int) -> Array:
	if fixed_order:
		return [0, 1, 2, 3, 4, 5, 6, 7] if endless_mode else [0, 1, 2, 3, 4]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_, "order"])
	var a := POOL_A.duplicate()
	var b := POOL_B.duplicate()
	_shuffle(a, rng)
	_shuffle(b, rng)
	var out := [0, a[0], a[1], b[0], b[1]]
	if endless_mode:
		out.append_array([a[2], b[2], b[3]])
	return out


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


## 무한 모드 회차 (모든 테마를 한 바퀴 돌 때마다 1씩)
static func cycle_of(wave: int) -> int:
	return maxi(stage_of(wave) - (ORDER.size() - 1), 0) / maxi(ORDER.size() - 1, 1) if wave > LAST_WAVE else 0


## 입구별 길이 상한
static func max_path(wave: int) -> int:
	return PATH_BASE + PATH_STEP * mini(stage_of(wave), 4)


## 연못 상태: 물(길·포탑 불가) · 얼음(길 가능, 빙판) · 마른 땅(모두 가능) · 용암(불가)
static func pond_state(theme: int) -> String:
	return ["water", "ice", "dry", "lava", "water", "bog", "water", "dry"][clampi(theme, 0, 7)]


static func in_rects(c: Vector2i, rects: Array) -> bool:
	for r in rects:
		if (r as Rect2i).has_point(c):
			return true
	return false


const SPEED_MUL := 1.3       # 큰 맵: 길이 길어진 만큼 적이 빠르다
const HIGH_RANGE := 1.0       # 높은 땅 사거리 보너스 (칸)


static func is_river(c: Vector2i) -> bool:
	return in_rects(c, RIVERS)


static func is_bridge(c: Vector2i) -> bool:
	return in_rects(c, BRIDGES)


static func is_high(c: Vector2i) -> bool:
	return in_rects(c, HIGH)


static func is_pond(c: Vector2i) -> bool:
	return in_rects(c, PONDS)


static func is_old_road(c: Vector2i, theme: int) -> bool:
	return str(THEMES[theme]["zone"]) == "sand" and in_rects(c, OLD_ROADS)


## 용암 균열 옆 칸 (화산부터 포탑 금지)
static func near_crack(c: Vector2i) -> bool:
	for k in CRACKS:
		if absi(k.x - c.x) <= 1 and absi(k.y - c.y) <= 1 and k != c:
			return true
	return false


const THEMES := [
	{"id": "grass", "px": ["#86827A", "#928E85", "#B08A34", "#4A4740"], "name": "초원", "desc": "길 그리기와 포켓 활용 배우기", "landmark": "굴착기", "zone": "", "wipe": "#3F5B31", "road": [["#000000", 0.98, 0, 0.35], ["#5A4A36", 0.94, 0, 1], ["#B39468", 0.74, 0, 1], ["#C9AD80", 0.3, 0, 0.45], ["#9A7C54", 0.05, 1, 0.8]]},
	{"id": "snow", "px": ["#8A949A", "#97A0A5", "#B08A34", "#55606A"], "name": "설원", "desc": "연못이 얼어 그 위로 길을 낼 수 있어요 · 얼음 길은 빙판", "landmark": "얼어붙은 시추기", "zone": "ice", "wipe": "#DCE8EE", "road": [["#000000", 0.98, 0, 0.35], ["#66767F", 0.94, 0, 1], ["#8F9DA5", 0.74, 0, 1], ["#AAB6BD", 0.3, 0, 0.45], ["#78858D", 0.05, 1, 0.8]]},
	{"id": "sand", "px": ["#6E685F", "#7A746A", "#C49C36", "#3E3A34"], "name": "사막", "desc": "옛 도로 칸은 자재 0 · 모래바람 구역은 포탑 사거리 감소", "landmark": "모래에 잠긴 수송차", "zone": "sand", "wipe": "#C9A566", "road": [["#000000", 0.98, 0, 0.35], ["#6E6253", 0.94, 0, 1], ["#8A7F71", 0.74, 0, 1], ["#A1968A", 0.3, 0, 0.45], ["#6C6256", 0.05, 1, 0.8]]},
	{"id": "lava", "px": ["#4E4844", "#5A534E", "#C46A2A", "#1A1716"], "name": "화산", "desc": "균열을 지나는 적은 지속 피해 · 균열 옆에는 포탑 금지", "landmark": "파손된 용광로", "zone": "lava", "wipe": "#7A2412", "road": [["#000000", 0.98, 0, 0.35], ["#1D1918", 0.94, 0, 1], ["#6A615A", 0.74, 0, 1], ["#7D736B", 0.3, 0, 0.45], ["#4E3A33", 0.05, 1, 0.8]]},
	{"id": "ghost", "px": ["#5A6058", "#666D64", "#6FA894", "#1E221F"], "name": "유령 숲", "desc": "막힌 땅이 열리며 새 입구가 생겨요", "landmark": "거목 급수탑", "zone": "ghost", "wipe": "#2B3F36", "road": [["#000000", 0.98, 0, 0.35], ["#2A2F2A", 0.94, 0, 1], ["#6A7066", 0.74, 0, 1], ["#7D8479", 0.3, 0, 0.45], ["#53594F", 0.05, 1, 0.8]]},
	{"id": "bog", "px": ["#5E5A48", "#6A6652", "#9AB040", "#262418"], "name": "늪 정제소", "desc": "연못이 늪이 돼 길을 낼 수 있어요 · 늪 길 위 적은 느리고 기름 범벅", "landmark": "녹슨 정제탑", "zone": "bog", "wipe": "#4A5230", "road": [["#000000", 0.98, 0, 0.35], ["#3A3626", 0.94, 0, 1], ["#6E6A52", 0.74, 0, 1], ["#827E64", 0.3, 0, 0.45], ["#55513E", 0.05, 1, 0.8]]},
	{"id": "storm", "px": ["#6A707C", "#767C88", "#E8D04A", "#262A32"], "name": "폭풍 고원", "desc": "낙뢰 표시가 뜬 칸에 1.5초 뒤 번개 · 맞은 적은 감전, 근처 포탑은 과부하", "landmark": "쓰러진 송전탑", "zone": "storm", "wipe": "#3A4252", "road": [["#000000", 0.98, 0, 0.35], ["#3A3F4A", 0.94, 0, 1], ["#727886", 0.74, 0, 1], ["#868C98", 0.3, 0, 0.45], ["#585E6A", 0.05, 1, 0.8]]},
	{"id": "scrap", "px": ["#6E6458", "#7A7062", "#C87A3A", "#2A2420"], "name": "고철 처리장", "desc": "자석 크레인 구역 안의 적은 자성 · 쓰러진 적은 고철 더미를 남겨요", "landmark": "멈춘 자석 크레인", "zone": "scrap", "wipe": "#5A4A3A", "road": [["#000000", 0.98, 0, 0.35], ["#3E352C", 0.94, 0, 1], ["#7A6E60", 0.74, 0, 1], ["#8E8272", 0.3, 0, 0.45], ["#5E5446", 0.05, 1, 0.8]]},
]

const ICE_SPEED := 1.3
const BOG_SPEED := 0.75       # 늪 길 위 적 속도 (기름 상태가 붙는다)
const STORM_EVERY := 16.0     # 폭풍 고원: 낙뢰 주기 (초)
const STORM_BOLTS := 3        # 한 번에 떨어지는 칸 수
const STORM_WARN := 1.5       # 표시 뒤 떨어지기까지
const STORM_R := 0.9          # 맞는 적 반경 (칸)
const STORM_OVER := 2.0       # 근처 포탑 과부하 (공격 속도 2배, 초)
const STORM_TOWER_R := 1.5
const SCRAP_MAG := 1.5        # 고철 처리장: 나올 때 자성 (기본 시간 ×1.5)
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
## st: 남기는 상태, st_mul: 상태 시간 배율, phys: 물리 피해(취성 +50%), every: n발마다 상태, vs_mag: 자성 적 추가 피해,
## mag: 자성이 깎는 방어력, pull/push: 끌어당김·밀어냄(칸), puddle: 맞은 자리 길에 기름 웅덩이(초), haste: 주변 공격 속도, mark_r: 표식 범위
const TOWERS := {
	"gun": {
		"name": "기관포탑", "role": "단일 연사", "cost": 100, "up": [80, 120], "art": 0,
		"lv": [{"dmg": 5.0, "cd": 0.3, "range": 3.0, "phys": true}, {"dmg": 8.0, "cd": 0.3, "range": 3.0, "phys": true}],
		"a": {"label": "예광탄", "desc": "5발마다 표식", "dmg": 8.0, "cd": 0.25, "range": 3.0, "phys": true, "st": "mark", "every": 5},
		"b": {"label": "철갑탄", "desc": "방어 무시 · 자성 +30%", "dmg": 16.0, "cd": 0.45, "range": 3.4, "phys": true, "pierce": 99.0, "vs_mag": 0.3},
	},
	"cannon": {
		"name": "대포탑", "role": "범위 한 방", "cost": 150, "up": [120, 180], "art": 1,
		"lv": [{"dmg": 16.0, "cd": 1.6, "range": 2.5, "splash": 1.0, "phys": true}, {"dmg": 24.0, "cd": 1.6, "range": 2.5, "splash": 1.0, "phys": true}],
		"a": {"label": "소이탄", "desc": "폭발 자리 화상", "dmg": 24.0, "cd": 1.6, "range": 2.5, "splash": 1.2, "st": "burn", "fire": true},
		"b": {"label": "고폭탄", "desc": "한 방 52 · 산산조각", "dmg": 52.0, "cd": 1.6, "range": 2.5, "splash": 1.0, "phys": true},
	},
	"cold": {
		"name": "냉각탑", "role": "범위 감속", "cost": 120, "up": [100, 140], "art": 2,
		"lv": [{"dmg": 1.0, "cd": 1.0, "range": 2.0, "aura": true, "st": "cold"}, {"dmg": 2.0, "cd": 0.8, "range": 2.0, "aura": true, "st": "cold"}],
		"a": {"label": "냉기 장막", "desc": "범위 3칸", "dmg": 2.0, "cd": 0.8, "range": 3.0, "aura": true, "st": "cold"},
		"b": {"label": "얼음 송곳", "desc": "한 방 + 냉기 2배", "dmg": 42.0, "cd": 1.6, "range": 2.5, "phys": true, "st": "cold", "st_mul": 2.0},
	},
	"magnet": {
		"name": "자석탑", "role": "방어 깎기", "cost": 140, "up": [110, 150], "art": 5,
		"lv": [{"dmg": 2.0, "cd": 0.8, "range": 2.5, "st": "mag"}, {"dmg": 3.0, "cd": 0.6, "range": 2.5, "st": "mag"}],
		"a": {"label": "강자장", "desc": "범위 끌어당김", "dmg": 2.0, "cd": 0.8, "range": 2.5, "aura": true, "st": "mag", "pull": 0.15},
		"b": {"label": "파쇄 자장", "desc": "자성 방어 -4", "dmg": 8.0, "cd": 0.6, "range": 2.5, "st": "mag", "mag": 4.0},
	},
	"oil": {
		"name": "기름분사탑", "role": "상태 깔기", "cost": 110, "up": [90, 130], "art": 3,
		"lv": [{"dmg": 1.0, "cd": 1.0, "range": 2.0, "splash": 0.8, "st": "oil"}, {"dmg": 1.0, "cd": 0.8, "range": 2.0, "splash": 1.0, "st": "oil"}],
		"a": {"label": "기름 웅덩이", "desc": "길 2칸 6초", "dmg": 1.0, "cd": 0.8, "range": 2.0, "splash": 1.0, "st": "oil", "puddle": 6.0},
		"b": {"label": "고압 분사", "desc": "사거리 3.5 · 밀어냄", "dmg": 1.0, "cd": 0.6, "range": 3.5, "splash": 1.4, "st": "oil", "push": 0.3},
	},
	"flame": {
		"name": "불꽃탑", "role": "근거리 지속", "cost": 130, "up": [100, 150], "art": 4,
		"lv": [{"dmg": 3.0, "cd": 0.25, "range": 1.5, "aura": true, "fire": true, "st": "burn"}, {"dmg": 4.5, "cd": 0.25, "range": 1.5, "aura": true, "fire": true, "st": "burn"}],
		"a": {"label": "화염 방사", "desc": "줄기 3칸", "dmg": 5.0, "cd": 0.25, "range": 3.0, "line": true, "fire": true, "st": "burn"},
		"b": {"label": "소각로", "desc": "화상 2배 시간", "dmg": 6.0, "cd": 0.25, "range": 1.5, "aura": true, "fire": true, "st": "burn", "st_mul": 2.0},
	},
	"shock": {
		"name": "전기탑", "role": "연쇄", "cost": 160, "up": [130, 170], "art": 6,
		"lv": [{"dmg": 10.0, "cd": 1.2, "range": 2.5, "chain": 4, "jump": 1.5, "st": "shock"}, {"dmg": 14.0, "cd": 1.2, "range": 2.5, "chain": 4, "jump": 1.5, "st": "shock"}],
		"a": {"label": "콘덴서", "desc": "4초 모아 한 방 60", "dmg": 60.0, "cd": 4.0, "range": 2.8, "st": "shock"},
		"b": {"label": "전기 울타리", "desc": "길 감전 장판", "dmg": 8.0, "cd": 1.0, "range": 2.5, "splash": 1.0, "st": "shock"},
	},
	"sniper": {
		"name": "저격탑", "role": "아주 먼 한 방", "cost": 170, "up": [140, 180], "art": 7,
		"lv": [{"dmg": 60.0, "cd": 2.5, "range": 6.0, "phys": true}, {"dmg": 85.0, "cd": 2.5, "range": 6.0, "phys": true}],
		"a": {"label": "표식탄", "desc": "맞은 적 표식", "dmg": 85.0, "cd": 2.2, "range": 6.5, "phys": true, "st": "mark"},
		"b": {"label": "열선탄", "desc": "한 방 + 화상", "dmg": 85.0, "cd": 2.2, "range": 6.0, "fire": true, "st": "burn"},
	},
	"signal": {
		"name": "신호탑", "role": "보조", "cost": 120, "up": [100, 130], "art": 8,
		"lv": [{"range": 2.0, "buff": 0.15, "reveal": true, "support": true, "st": "mark", "mark_r": 1.5}, {"range": 2.0, "buff": 0.2, "reveal": true, "support": true, "st": "mark", "mark_r": 1.5}],
		"a": {"label": "지휘소", "desc": "주변 공격 속도 +15%", "range": 2.5, "buff": 0.2, "reveal": true, "support": true, "st": "mark", "mark_r": 1.5, "haste": 0.15},
		"b": {"label": "조준 레이저", "desc": "표식 범위 2칸", "range": 2.0, "buff": 0.2, "reveal": true, "support": true, "st": "mark", "mark_r": 2.5},
	},
	"spike": {
		"name": "가시 덫개", "role": "길 위 함정", "cost": 60, "up": [50, 80], "art": 9,
		"lv": [{"dmg": 20.0, "range": 0.5, "trap": true, "uses": 30, "phys": true}, {"dmg": 30.0, "range": 0.5, "trap": true, "uses": 40, "phys": true}],
		"a": {"label": "지뢰", "desc": "터지며 화상", "dmg": 60.0, "range": 0.5, "trap": true, "uses": 3, "splash": 1.0, "fire": true, "st": "burn"},
		"b": {"label": "끈끈이", "desc": "기름 + 감속", "dmg": 10.0, "range": 0.5, "trap": true, "uses": 60, "slow": 0.4, "st": "oil"},
	},
	"steam": {
		"name": "증기탑", "role": "범위 지속", "cost": 130, "up": [100, 150], "art": 10,
		"lv": [{"dmg": 3.0, "cd": 0.6, "range": 1.8, "aura": true, "st_alt": true}, {"dmg": 4.0, "cd": 0.5, "range": 1.8, "aura": true, "st_alt": true}],
		"a": {"label": "압력솥", "desc": "5초마다 큰 분출", "dmg": 40.0, "cd": 5.0, "range": 2.4, "aura": true, "st_alt": true},
		"b": {"label": "안개", "desc": "유령·굴착 적 드러냄", "dmg": 4.0, "cd": 0.5, "range": 2.2, "aura": true, "st": "cold", "reveal": true},
	},
	"crane": {
		"name": "크레인탑", "role": "큰 적 처리", "cost": 150, "up": [120, 170], "art": 11,
		"lv": [{"dmg": 34.0, "cd": 2.6, "range": 2.6, "phys": true}, {"dmg": 44.0, "cd": 2.4, "range": 2.6, "phys": true}],
		"a": {"label": "들었다 놓기", "desc": "한 방 50 + 1초 기절", "dmg": 50.0, "cd": 2.4, "range": 2.6, "phys": true, "stun": 1.0},
		"b": {"label": "자석 갈고리", "desc": "자성 + 뒤로 1칸", "dmg": 30.0, "cd": 2.2, "range": 2.6, "phys": true, "st": "mag", "push": 1.0},
	},
	"generator": {
		"name": "발전기", "role": "보조", "cost": 100, "up": [80, 120], "art": 12,
		"lv": [{"range": 2.0, "support": true, "volt": 0.2}, {"range": 2.5, "support": true, "volt": 0.3}],
		"a": {"label": "고압 변전소", "desc": "주변 전기 연쇄 +2", "range": 2.5, "support": true, "volt": 0.3, "chain_up": 2},
		"b": {"label": "비상 배터리", "desc": "긴급 냉각 +1회", "range": 2.5, "support": true, "volt": 0.2, "battery": 1},
	},
	"conveyor": {
		"name": "컨베이어", "role": "길 위 함정", "cost": 80, "up": [60, 90], "art": 13,
		"lv": [{"dmg": 4.0, "range": 0.5, "trap": true, "uses": 40, "slow": 0.2}, {"dmg": 6.0, "range": 0.5, "trap": true, "uses": 50, "slow": 0.25}],
		"a": {"label": "역회전", "desc": "적을 1칸 뒤로", "dmg": 6.0, "range": 0.5, "trap": true, "uses": 30, "knock": 1.0},
		"b": {"label": "속도 조절", "desc": "위의 적 감속 40%", "dmg": 6.0, "range": 0.5, "trap": true, "uses": 60, "slow": 0.4},
	},
	"welder": {
		"name": "용접탑", "role": "근거리 빔", "cost": 140, "up": [110, 150], "art": 14,
		"lv": [{"dmg": 4.0, "cd": 0.2, "range": 1.8, "fire": true, "st": "burn"}, {"dmg": 6.0, "cd": 0.2, "range": 1.8, "fire": true, "st": "burn"}],
		"a": {"label": "플라스마", "desc": "화상 + 감전", "dmg": 6.0, "cd": 0.2, "range": 1.8, "fire": true, "st": "burn", "st2": "shock"},
		"b": {"label": "절단기", "desc": "같은 적이면 피해 누적 ×3", "dmg": 6.0, "cd": 0.2, "range": 1.8, "phys": true, "ramp": 3.0},
	},
	"cryo": {
		"name": "냉동 미사일", "role": "장거리 범위", "cost": 180, "up": [140, 180], "art": 15,
		"lv": [{"dmg": 18.0, "cd": 2.4, "range": 5.0, "splash": 1.0, "st": "cold"}, {"dmg": 26.0, "cd": 2.2, "range": 5.0, "splash": 1.0, "st": "cold"}],
		"a": {"label": "집속탄", "desc": "한 방 40 · 산산조각", "dmg": 42.0, "cd": 2.2, "range": 5.0, "splash": 0.6, "phys": true, "st": "cold"},
		"b": {"label": "확산탄", "desc": "범위 2칸 냉기", "dmg": 16.0, "cd": 2.2, "range": 5.0, "splash": 2.0, "st": "cold"},
	},
	"searchlight": {
		"name": "탐조등", "role": "보조", "cost": 90, "up": [70, 100], "art": 16,
		"lv": [{"range": 3.0, "support": true, "reveal": true, "st": "mark", "mark_r": 3.0}, {"range": 3.5, "support": true, "reveal": true, "st": "mark", "mark_r": 3.5}],
		"a": {"label": "서치라이트", "desc": "사거리 5칸", "range": 5.0, "support": true, "reveal": true, "st": "mark", "mark_r": 5.0},
		"b": {"label": "섬광", "desc": "0.5초 기절 + 표식", "range": 3.0, "support": true, "reveal": true, "st": "mark", "mark_r": 3.0, "flash": 0.5},
	},
	"scrap": {
		"name": "고철 투척기", "role": "범위 물리", "cost": 120, "up": [100, 140], "art": 17,
		"lv": [{"dmg": 16.0, "cd": 1.4, "range": 3.0, "splash": 0.8, "phys": true, "st": "mag"}, {"dmg": 22.0, "cd": 1.3, "range": 3.0, "splash": 0.8, "phys": true, "st": "mag"}],
		"a": {"label": "고철 더미", "desc": "맞은 자리 자성 장판 4초", "dmg": 22.0, "cd": 1.3, "range": 3.0, "splash": 0.8, "phys": true, "st": "mag", "puddle": 4.0, "puddle_st": "mag"},
		"b": {"label": "강철구", "desc": "한 방 45 · 산산조각", "dmg": 45.0, "cd": 1.6, "range": 3.0, "phys": true},
	},
	"railgun": {
		"name": "레일건", "role": "합동 · 일직선 관통", "cost": 400, "up": [0, 0], "joint": true, "art": 0,
		"lv": [{"dmg": 120.0, "cd": 4.0, "range": 60.0, "rail": true, "phys": true, "vs_shock": 0.5}, {"dmg": 120.0, "cd": 4.0, "range": 60.0, "rail": true, "phys": true, "vs_shock": 0.5}],
		"a": {"dmg": 120.0, "cd": 4.0, "range": 60.0, "rail": true}, "b": {"dmg": 120.0, "cd": 4.0, "range": 60.0, "rail": true},
	},
	"chiller": {
		"name": "대형 냉각기", "role": "합동 · 반지름 4칸 냉기", "cost": 360, "up": [0, 0], "joint": true, "art": 1,
		"lv": [{"dmg": 3.0, "cd": 0.8, "range": 4.0, "aura": true, "st": "cold"}, {"dmg": 3.0, "cd": 0.8, "range": 4.0, "aura": true, "st": "cold"}],
		"a": {"dmg": 3.0, "cd": 0.8, "range": 4.0, "aura": true, "st": "cold"}, "b": {"dmg": 3.0, "cd": 0.8, "range": 4.0, "aura": true, "st": "cold"},
	},
	"smelter": {
		"name": "제철로", "role": "합동 · 용암 줄기", "cost": 380, "up": [0, 0], "joint": true, "art": 2,
		"lv": [{"dmg": 12.0, "cd": 0.5, "range": 3.0, "line": true, "fire": true, "st": "burn", "puddle": 3.0, "puddle_st": "burn"}, {"dmg": 12.0, "cd": 0.5, "range": 3.0, "line": true, "fire": true, "st": "burn", "puddle": 3.0, "puddle_st": "burn"}],
		"a": {"dmg": 12.0, "cd": 0.5, "range": 3.0, "line": true}, "b": {"dmg": 12.0, "cd": 0.5, "range": 3.0, "line": true},
	},
	"relay": {
		"name": "중계탑", "role": "합동 · 포탑 3개 연결", "cost": 320, "up": [0, 0], "joint": true, "art": 3,
		"lv": [{"range": 2.0, "support": true, "relay": 3}, {"range": 2.0, "support": true, "relay": 3}],
		"a": {"range": 2.0, "support": true, "relay": 3}, "b": {"range": 2.0, "support": true, "relay": 3},
	},
}

# ── 상태와 반응 ──
## 상태: 한 적에 같은 상태는 겹치지 않고 시간만 새로. 두 상태가 만나면 반응.
const STATUS := {
	"oil": {"name": "기름", "col": "#5A3E28", "t": 4.0},
	"burn": {"name": "화상", "col": "#F07A2A", "t": 3.0},
	"cold": {"name": "냉기", "col": "#8FD3F0", "t": 2.0},
	"shock": {"name": "감전", "col": "#F2D640", "t": 3.0},
	"mag": {"name": "자성", "col": "#A070E0", "t": 4.0},
	"mark": {"name": "표식", "col": "#F4F1E8", "t": 5.0},
}
const STATUS_ORDER := ["oil", "burn", "cold", "shock", "mag", "mark"]
static var BURN_DPS := 6.0
static var RX_DMG := 1.6         # 반응 피해 배율 (밸런스)
const OIL_SLOW := 0.1
const COLD_SLOW := 0.3
const MAG_ARMOR := 2.0
const MARK_TAKEN := 0.1
const CROSS_BONUS := 0.25      # 다른 사람 포탑끼리 만든 반응 피해
const RX_COOLDOWN := 1.0
## 반응: a+b 두 상태 (자성·표식은 반응 뒤에도 남는다). shatter·slip·amp 는 특별 조건.
const REACTIONS := {
	"ignite": {"name": "인화", "a": "oil", "b": "burn", "col": "#F08A3A", "desc": "반지름 1칸 폭발 30"},
	"harden": {"name": "굳음", "a": "oil", "b": "cold", "col": "#9CC8DC", "desc": "1.5초 멈춤 (보스 0.4초)"},
	"short": {"name": "합선", "a": "oil", "b": "shock", "col": "#E8D04A", "desc": "2칸 안 기름 묻은 적 모두 20"},
	"thermal": {"name": "열충격", "a": "cold", "b": "burn", "col": "#E8A0A0", "desc": "방어 영구 -1 (최대 -3), 15"},
	"super": {"name": "초전도", "a": "cold", "b": "shock", "col": "#A8E8F8", "desc": "주변 3명에게 줄지 않는 번개"},
	"brittle": {"name": "취성", "a": "cold", "b": "mag", "col": "#C8B8F0", "desc": "4초 물리 피해 +50%"},
	"emag": {"name": "전자석", "a": "mag", "b": "shock", "col": "#B890F0", "desc": "1.5칸 적을 끌어모음"},
	"melt": {"name": "가열 장갑", "a": "mag", "b": "burn", "col": "#E07060", "desc": "3초 방어력 0"},
	"overheat": {"name": "과열", "a": "shock", "b": "burn", "col": "#F8B030", "desc": "주변 1칸 25, 화상 퍼짐"},
	"shatter": {"name": "산산조각", "a": "cold", "b": "", "col": "#E0F4FF", "desc": "냉기 + 한 방 40 이상 = ×1.5"},
	"slip": {"name": "미끄럼", "a": "oil", "b": "", "col": "#C0A070", "desc": "기름 + 덫 = 덫 피해 ×2, 넘어짐"},
	"amp": {"name": "증폭", "a": "mark", "b": "", "col": "#FFFFFF", "desc": "표식 + 반응 = 반응 피해 ×2"},
}
const REACTION_ORDER := ["ignite", "harden", "short", "thermal", "super", "brittle", "emag", "melt", "overheat", "shatter", "slip", "amp"]


static func reaction_of(a: String, b: String) -> String:
	for k in REACTION_ORDER:
		var r: Dictionary = REACTIONS[k]
		if r["b"] != "" and ((r["a"] == a and r["b"] == b) or (r["a"] == b and r["b"] == a)):
			return k
	return ""


## 그 상태로 터뜨릴 수 있는 반응들
static func reactions_with(st: String) -> Array:
	var out := []
	for k in REACTION_ORDER:
		var r: Dictionary = REACTIONS[k]
		if r["a"] == st or r["b"] == st:
			out.append(k)
	return out


const TOWER_ORDER := ["gun", "cannon", "cold", "magnet", "oil", "flame", "shock", "sniper", "signal", "spike",
	"steam", "crane", "generator", "conveyor", "welder", "cryo", "searchlight", "scrap"]
const DEFAULT_KIT := ["gun", "cannon", "cold", "spike"]
## 테마가 지날수록 열리는 포탑 (초원은 기존 10종)
const UNLOCK := [["gun", "cannon", "cold", "magnet", "oil", "flame", "shock", "sniper", "signal", "spike"],
	["steam", "cryo", "searchlight"], ["crane", "scrap", "welder"], ["generator", "conveyor"], []]


## 이 포탑이 상태를 남기는지 (증기탑처럼 번갈아 남기는 것도)
static func leaves_status(type: String) -> bool:
	for r in TOWERS[type]["lv"]:      # 기본 단계 (갈래는 branch_status)
		if str(r.get("st", "")) != "" or bool(r.get("st_alt", false)) or str(r.get("st2", "")) != "":
			return true
	return false


static func branch_status(type: String, branch: String) -> bool:
	var r: Dictionary = TOWERS[type][branch]
	return str(r.get("st", "")) != "" or bool(r.get("st_alt", false)) or str(r.get("st2", "")) != ""


static func is_joint(type: String) -> bool:
	return TOWERS.has(type) and bool(TOWERS[type].get("joint", false))


static func unlocked(wave: int) -> Array:
	var out := []
	for t in stage_of(wave) + 1:
		for k in UNLOCK[mini(t, UNLOCK.size() - 1)]:
			if TOWERS.has(k) and not out.has(k):
				out.append(k)
	return out


## 이번 웨이브에 새로 열린 포탑
static func fresh_unlocks(wave: int) -> Array:
	if (wave - 1) % THEME_LEN != 0 or wave <= 1:
		return []
	return (UNLOCK[mini(stage_of(wave), UNLOCK.size() - 1)] as Array).filter(func(k): return TOWERS.has(k))
const TRAP_REPAIR := 1
## 역할: 대기실에서 하나씩, 같은 역할은 한 명만. 패시브 1 + 웨이브당 1번 R 능력
const ROLES := {
	"chief": {"name": "반장", "passive": "공사 자재 웨이브당 +2 · 길을 제안 없이 바로 확정", "ability": "긴급 방벽", "ab_desc": "길 한 칸을 8초 막아 적이 멈춤", "job": "길과 맵 모양", "col": "#E9B935"},
	"supply": {"name": "보급", "passive": "웨이브마다 나에게 +60골드 · 골드 주기 +20%", "ability": "보급품 투하", "ab_desc": "팀원에게 다시 뽑기 1회 + 80골드", "job": "돈을 모아 필요한 사람에게", "col": "#38A672"},
	"mech": {"name": "정비", "passive": "남의 포탑 투자 20% 할인", "ability": "과부하 운전", "ab_desc": "포탑 하나 10초 공격 속도 x2", "job": "팀원 포탑을 키운다", "col": "#3D6FD1"},
	"fire": {"name": "화력", "passive": "내 포탑 피해 +10% · 고르기 카드 7장", "ability": "일제 사격", "ab_desc": "5초 동안 내 포탑 반응 피해 x2", "job": "주 피해를 맡는다", "col": "#D9503C"},
}
const ROLE_ORDER := ["chief", "supply", "mech", "fire"]
const BOT_ROLE := ["supply", "mech", "fire", "chief"]      # 연습 동료가 고르는 순서
const CHIEF_MAT := 2
const SUPPLY_GOLD := 60
const GIVE_BONUS := 0.2
const MECH_DISCOUNT := 0.2
const FIRE_DMG := 0.1
const WALL_TIME := 8.0
const DROP_GOLD := 80
const OVERLOAD_TIME := 10.0
const VOLLEY_TIME := 5.0
## 합동 설비: 2x2, 두 사람 이상이 내야 완성. 기초는 40%, 테마당 한 팀 1개 (최대 5)
const JOINT_ORDER := ["railgun", "chiller", "smelter", "relay"]
const JOINT_FOUND := 0.4
const JOINT_CHIP := 0.25      # 기여 한 번 = 합계의 25% (10골드 단위)
const RELAY_RANGE := 1.0
const RELAY_HASTE := 0.2
const SHARED_DMG := 0.1      # 합류한 공동 구간 2칸 안 포탑 피해 +10%
const SHARED_NEAR := 2
const CROSS_WAIT := 0.3      # 교차로를 지나는 적이 멈칫하는 시간
const RELAY_RX := 0.25
const INVEST_SHARE := 0.25    # 투자 한 번 = 다음 강화비의 25% (10골드 단위로 내림)
const INVEST_AUTO := 5.0      # 주인이 없으면 게이지가 찬 뒤 5초에 자동 강화        # 가시 덫개 수리에 드는 공사 자재

# ── 적 ──
## heal 초당 회복(heal_r 칸 안), ice 빙판 위 속도 배율, slow_res 감속 저항, burrow [주기, 땅속 시간],
## guard 주변 적 보호막, fireproof 불·용암 면역, split [작은 적, 수], phase [주기, 조준 불가 시간],
## trail 지나간 칸 빙판(초), drops [체력 비율들, 적, 수], overheat [주기, 반경, 시간], clone 분신 체력 비율
const ENEMIES := {
	"grunt": {"name": "일반병", "hp": 34.0, "armor": 0.0, "speed": 1.25, "hit": 1, "price": 1.0, "look": [0, ""]},
	"swarm": {"name": "떼거리", "hp": 13.0, "armor": 0.0, "speed": 1.6, "hit": 1, "price": 0.5, "look": [3, ""]},
	"heavy": {"name": "중장갑", "hp": 120.0, "armor": 4.0, "speed": 0.8, "hit": 1, "price": 4.0, "look": [2, ""]},
	"rusher": {"name": "돌격병", "hp": 42.0, "armor": 0.0, "speed": 2.4, "hit": 1, "price": 1.5, "look": [1, ""]},
	"healer": {"name": "치유사", "hp": 50.0, "armor": 0.0, "speed": 1.1, "hit": 1, "price": 3.0, "heal": 5.0, "heal_r": 2.0, "look": [4, ""]},
	"sled": {"name": "썰매병", "hp": 40.0, "armor": 0.0, "speed": 1.5, "hit": 1, "price": 2.0, "ice": 2.0, "look": [6, ""]},
	"shield": {"name": "방패병", "hp": 70.0, "armor": 2.0, "speed": 1.0, "hit": 1, "price": 3.0, "slow_res": 0.5, "look": [7, ""]},
	"worm": {"name": "굴착 벌레", "hp": 60.0, "armor": 0.0, "speed": 1.2, "hit": 1, "price": 3.0, "burrow": [3.0, 1.5], "look": [8, ""]},
	"carrier": {"name": "방패 수송차", "hp": 150.0, "armor": 2.0, "speed": 0.7, "hit": 1, "price": 5.0, "guard": 30.0, "look": [9, ""]},
	"golem": {"name": "내열 골렘", "hp": 160.0, "armor": 6.0, "speed": 0.75, "hit": 1, "price": 5.0, "fireproof": true, "look": [10, ""]},
	"splitter": {"name": "분열체", "hp": 80.0, "armor": 0.0, "speed": 1.0, "hit": 1, "price": 3.0, "split": ["mini", 2], "look": [11, ""]},
	"mini": {"name": "작은 분열체", "hp": 25.0, "armor": 0.0, "speed": 1.6, "hit": 1, "price": 0.0, "look": [12, ""]},
	"phantom": {"name": "유령병", "hp": 55.0, "armor": 0.0, "speed": 1.2, "hit": 1, "price": 3.0, "phase": [5.0, 2.0], "look": [13, ""]},
	"vine": {"name": "덩굴 치유사", "hp": 70.0, "armor": 0.0, "speed": 1.0, "hit": 1, "price": 4.0, "heal": 4.0, "heal_r": 2.0, "slow_res": 1.0, "look": [14, ""]},
	"boss": {"name": "초원 대장", "hp": 380.0, "armor": 3.0, "speed": 0.62, "hit": 15, "price": 0.0, "boss": true, "look": [5, ""], "skill": ""},
	"walker": {"name": "쇄빙 보행기", "hp": 470.0, "armor": 3.0, "speed": 0.6, "hit": 15, "price": 0.0, "boss": true, "trail": 5.0, "look": [22, ""], "skill": "지나간 길을 5초 동안 빙판으로"},
	"fortress": {"name": "모래 수송 요새", "hp": 560.0, "armor": 4.0, "speed": 0.5, "hit": 15, "price": 0.0, "boss": true, "drops": [[0.5, 0.0], "swarm", 8], "look": [23, ""], "skill": "체력 50%·0%에서 떼거리 8명"},
	"giant": {"name": "용광로 거인", "hp": 640.0, "armor": 5.0, "speed": 0.55, "hit": 15, "price": 0.0, "boss": true, "overheat": [8.0, 2.0, 2.0], "fireproof": true, "look": [24, ""], "skill": "8초마다 주변 포탑 과열"},
	"shadow": {"name": "그림자 사령관", "hp": 720.0, "armor": 3.0, "speed": 0.65, "hit": 15, "price": 0.0, "boss": true, "clone": 0.5, "look": [25, ""], "skill": "체력 50%에서 분신 소환"},
	"toad": {"name": "늪 두꺼비", "hp": 48.0, "armor": 0.0, "speed": 1.4, "hit": 1, "price": 2.5, "burrow": [3.5, 1.0], "look": [15, ""]},
	"sludge": {"name": "슬러지 통", "hp": 110.0, "armor": 2.0, "speed": 0.8, "hit": 1, "price": 4.0, "split": ["leech", 3], "look": [16, ""]},
	"leech": {"name": "거머리", "hp": 18.0, "armor": 0.0, "speed": 1.7, "hit": 1, "price": 0.0, "look": [17, ""]},
	"rod": {"name": "피뢰 보행기", "hp": 75.0, "armor": 3.0, "speed": 1.0, "hit": 1, "price": 3.5, "slow_res": 0.5, "shockproof": true, "look": [18, ""]},
	"kite": {"name": "돌풍 연", "hp": 36.0, "armor": 0.0, "speed": 1.9, "hit": 1, "price": 2.0, "phase": [4.0, 1.5], "flying": true, "look": [19, ""]},
	"scav": {"name": "고철 수집가", "hp": 90.0, "armor": 3.0, "speed": 0.95, "hit": 1, "price": 3.5, "guard": 20.0, "look": [20, ""]},
	"repair": {"name": "자가수리 로봇", "hp": 85.0, "armor": 1.0, "speed": 1.0, "hit": 1, "price": 3.5, "heal": 6.0, "heal_r": 1.2, "look": [21, ""]},
	"dredger": {"name": "준설 크롤러", "hp": 600.0, "armor": 4.0, "speed": 0.5, "hit": 15, "price": 0.0, "boss": true, "drops": [[0.66, 0.33], "toad", 5], "look": [26, ""], "skill": "체력 66%·33%에서 늪 두꺼비 5마리"},
	"stormship": {"name": "뇌운 함선", "hp": 620.0, "armor": 3.0, "speed": 0.6, "hit": 15, "price": 0.0, "boss": true, "overheat": [10.0, 2.5, 3.0], "look": [27, ""], "skill": "10초마다 주변 포탑 과열"},
	"crusher": {"name": "철갑 분쇄기", "hp": 680.0, "armor": 8.0, "speed": 0.5, "hit": 15, "price": 0.0, "boss": true, "drops": [[0.5], "scav", 3], "look": [28, ""], "skill": "방어 8 · 체력 50%에서 고철 수집가 3"},
}
## 테마별 전용 적과 보스 (전용 적은 앞 테마에서 통하던 전략을 하나씩 막는다)
const THEME_FOES := [["healer"], ["sled", "shield"], ["worm", "carrier"], ["golem", "splitter"], ["phantom", "vine"], ["toad", "sludge"], ["rod", "kite"], ["scav", "repair"]]
const THEME_BOSS := ["boss", "walker", "fortress", "giant", "shadow", "dredger", "stormship", "crusher"]
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


const FIRST_BOSS_HP := 0.75
static var HQ_GUN_AMMO := 10      # 본부 방어포: 첫 테마 웨이브마다 탄 수 (뒤로 갈수록 줄어든다, HQ_GUN_FALL)
const HQ_GUN_FALL := [1.0, 0.5, 0.25, 0.0]   # 테마 구간별 탄 배율 (4번째 테마부터 없음)
const HQ_GUN_RANGE := 3.0         # 본부 가장자리에서 칸
const HQ_GUN_CD := 0.5
const HQ_GUN_DMG := 0.4           # 한 발 = 그 웨이브 일반병 체력의 40%
static var EARLY_BUDGET := [0.4, 0.55, 0.7, 0.85, 1.0]   # 첫 테마 웨이브별 적 수 배율 (초반 완충)


static func wave_budget(wave: int, players: int) -> float:
	var early: float = EARLY_BUDGET[wave - 1] if wave <= EARLY_BUDGET.size() else 1.0
	return early * (20.0 + wave * 6.0) * float(budget_scale.get(clampi(players, 1, 4), 1.0)) * float(DIFFICULTY[difficulty][1])


static var EARLY_HP := [0.5, 0.6, 0.7, 0.85, 1.0]   # 첫 테마 웨이브별 적 체력 배율 (초반 완충)


static func wave_hp(wave: int, players := 2) -> float:
	var early: float = EARLY_HP[wave - 1] if wave <= EARLY_HP.size() else 1.0
	return early * pow(ENDLESS_HP, maxi(wave - LAST_WAVE, 0)) * (1.0 + maxi(wave - 6, 0) * HP_GROWTH) * float(hp_scale.get(clampi(players, 1, 4), 1.0)) * float(DIFFICULTY[difficulty][0])


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
	if theme == 0 and k < 3 and wave <= THEME_LEN:
		pass      # 첫 테마 1·2웨이브는 공통 적만 (전용 적은 3웨이브부터)
	elif k == 1:
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
		"support": bool(s.get("support", false)), "st": str(s.get("st", "")), "st_mul": float(s.get("st_mul", 1.0)),
		"phys": bool(s.get("phys", false)), "every": int(s.get("every", 0)), "vs_mag": float(s.get("vs_mag", 0.0)),
		"mag": float(s.get("mag", MAG_ARMOR)), "pull": float(s.get("pull", 0.0)), "push": float(s.get("push", 0.0)),
		"puddle": float(s.get("puddle", 0.0)), "haste": float(s.get("haste", 0.0)), "mark_r": float(s.get("mark_r", 0.0)),
		"st2": str(s.get("st2", "")), "st_alt": bool(s.get("st_alt", false)), "stun": float(s.get("stun", 0.0)),
		"ramp": float(s.get("ramp", 0.0)), "volt": float(s.get("volt", 0.0)), "chain_up": int(s.get("chain_up", 0)),
		"battery": int(s.get("battery", 0)), "knock": float(s.get("knock", 0.0)), "puddle_st": str(s.get("puddle_st", "oil")),
		"flash": float(s.get("flash", 0.0)), "rail": bool(s.get("rail", false)), "vs_shock": float(s.get("vs_shock", 0.0)),
		"relay": int(s.get("relay", 0)),
	}


static func _static_init() -> void:
	use_layout(2)
