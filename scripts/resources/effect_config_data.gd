class_name EffectConfigData
extends Resource

# 摄像机震动
@export var camera_shake_player_hit_intensity: float = 1.5
@export var camera_shake_player_hit_duration: float = 0.1
@export var camera_shake_enemy_kill_intensity: float = 1.0
@export var camera_shake_enemy_kill_duration: float = 0.08
@export var camera_shake_wave_start_intensity: float = 2.5
@export var camera_shake_wave_start_duration: float = 0.2

# 击退
@export var knockback_distance: float = 7.5
@export var knockback_duration: float = 0.1

# 受击闪白
@export var hit_flash_duration: float = 0.05
@export var hit_flash_color: Color = Color.WHITE

# 无敌帧闪烁
@export var invincible_blink_interval: float = 0.08
@export var invincible_blink_alpha_low: float = 0.3
@export var invincible_blink_alpha_high: float = 1.0

# 伤害数字
@export var damage_number_float_distance: float = 15.0
@export var damage_number_random_offset_x: float = 5.0
@export var damage_number_duration: float = 0.6
@export var damage_number_big_threshold: float = 30.0
@export var damage_number_big_scale: float = 1.3
@export var damage_number_normal_color: Color = Color.WHITE
@export var damage_number_big_color: Color = Color.YELLOW
@export var damage_number_z_index: int = 100

# 死亡粒子
@export var death_particle_count: int = 10
@export var death_particle_spread: float = 10.0
@export var death_particle_lifetime: float = 0.3
@export var death_particle_gravity: float = 100.0
@export var death_particle_speed_min: float = 25.0
@export var death_particle_speed_max: float = 60.0
@export var death_particle_z_index: int = 50

# 击中火花
@export var hit_spark_count: int = 5
@export var hit_spark_lifetime: float = 0.15
@export var hit_spark_spread_speed: float = 50.0
@export var hit_spark_z_index: int = 50

# 金币拾取
@export var coin_pickup_shrink_duration: float = 0.15

# 子弹拖尾
@export var bullet_trail_length: float = 7.5
@export var bullet_trail_width: float = 2.0
@export var bullet_trail_color: Color = Color(1, 1, 0, 0.6)
@export var bullet_trail_max_points: int = 4

# 回旋镖特效
@export var boomerang_rotation_speed: float = 720.0
@export var boomerang_trail_points: int = 6
@export var boomerang_trail_width: float = 3.0
@export var boomerang_trail_color: Color = Color(0.2, 0.8, 1.0, 0.6)
@export var boomerang_return_rotation_mult: float = 1.5
@export var boomerang_return_distance: float = 7.5

# 激光特效
@export var laser_beam_width: float = 3.0
@export var laser_beam_color: Color = Color(1, 0.2, 0.2, 0.9)
@export var laser_beam_hitbox_height: float = 8.0
@export var laser_core_color: Color = Color(1, 1, 1, 0.9)
@export var laser_edge_color: Color = Color(1, 0.2, 0.2, 0.7)
@export var laser_flash_alpha: float = 0.03
@export var laser_flash_duration: float = 0.05
@export var laser_flash_size: Vector2 = Vector2(1000, 1000)
@export var laser_flash_z_index: int = 90
@export var laser_ray_query_limit: int = 20
@export var laser_collision_mask: int = 2

# 摄像机
@export var camera_zoom: float = 1.0
@export var camera_smoothing_speed: float = 8.0
@export var camera_look_ahead_distance: float = 20.0
@export var camera_look_ahead_smoothing: float = 3.0
@export var camera_dead_zone_width: float = 0.1
@export var camera_dead_zone_height: float = 0.1

# 地图
@export var map_size_ratio: float = 0.95

# 枪口闪光
@export var muzzle_flash_size: Vector2 = Vector2(3, 3)
@export var muzzle_flash_color: Color = Color(1, 1, 0.8, 0.9)
@export var muzzle_flash_z_index: int = 10
@export var muzzle_flash_duration: float = 0.05
