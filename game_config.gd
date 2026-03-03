extends Node

# 游戏全局配置文件
# 用于快速调整游戏平衡性参数

class_name GameConfig

# ========== 玩家配置 ==========
const PLAYER_MAX_HP = 100
const PLAYER_MOVE_SPEED = 200.0
const PLAYER_HIT_COOLDOWN = 0.5  # 受击无敌时间

# ========== 武器配置 ==========
const WEAPON_RANGE = 400.0  # 自动索敌范围
const WEAPON_FIRE_RATE = 0.1  # 速射枪射击间隔（秒）
const WEAPON_DAMAGE = 10

# ========== 子弹配置 ==========
const BULLET_SPEED = 600.0
const BULLET_LIFETIME = 2.0  # 子弹存活时间（秒）

# ========== 敌人配置 ==========
const ENEMY_NORMAL_HP = 30
const ENEMY_NORMAL_SPEED = 80.0
const ENEMY_NORMAL_DAMAGE = 10
const ENEMY_NORMAL_COIN_DROP = 5

const ENEMY_FAST_HP = 20
const ENEMY_FAST_SPEED = 150.0
const ENEMY_FAST_DAMAGE = 8
const ENEMY_FAST_COIN_DROP = 8

const ENEMY_TANK_HP = 100
const ENEMY_TANK_SPEED = 50.0
const ENEMY_TANK_DAMAGE = 20
const ENEMY_TANK_COIN_DROP = 15

# ========== 植物塔配置 ==========
const TOWER_SHOOTER_HP = 80
const TOWER_SHOOTER_DAMAGE = 10
const TOWER_SHOOTER_FIRE_RATE = 1.0
const TOWER_SHOOTER_RANGE = 300.0
const TOWER_SHOOTER_COST = 30

const TOWER_WALL_HP = 300
const TOWER_WALL_COST = 40

const TOWER_SLOW_HP = 70
const TOWER_SLOW_RANGE = 200.0
const TOWER_SLOW_EFFECT = 0.5  # 减速 50%
const TOWER_SLOW_COST = 35

# ========== 波次配置 ==========
const WAVE_DURATION = [45, 45, 45, 50, 50, 50, 60, 60, 60, 60]  # 每波时长（秒）
const WAVE_SPAWN_INTERVAL = [2.0, 1.8, 1.5, 1.2, 1.0, 0.8, 0.6, 0.5, 0.4, 0.3]  # 刷怪间隔

# ========== 经济配置 ==========
const INITIAL_COINS = 50  # 初始金币
const COIN_PICKUP_RANGE = 100.0  # 自动吸附范围
const SHOP_REFRESH_COST = 10  # 商店刷新花费

# ========== 网格配置 ==========
const GRID_SIZE = 32  # 植物塔放置网格大小（像素）

# ========== 地图配置 ==========
const MAP_WIDTH = 3200
const MAP_HEIGHT = 2400

# ========== 摄像机配置 ==========
const CAMERA_ZOOM = Vector2(1.0, 1.0)
const CAMERA_SMOOTHING = 5.0
