# 音效资源需求清单

> 用于后续添加音效时的参考

## 一、必需音效（优先级：高）

### 战斗音效
- `shoot.ogg` - 玩家射击音效（短促，0.1-0.2秒）
- `hit.ogg` - 子弹命中敌人（轻微撞击声）
- `player_hurt.ogg` - 玩家受伤（痛苦声）
- `enemy_death.ogg` - 敌人死亡（消失音效）

### UI 音效
- `button_click.ogg` - 按钮点击
- `coin_pickup.ogg` - 拾取金币（清脆声）
- `purchase.ogg` - 商店购买成功
- `wave_start.ogg` - 波次开始提示音

### 植物塔音效
- `tower_place.ogg` - 放置植物塔
- `tower_shoot.ogg` - 豌豆射手发射
- `tower_destroyed.ogg` - 植物塔被摧毁

## 二、可选音效（优先级：中）

### 特殊效果
- `slow_effect.ogg` - 冰雪菇减速效果（持续音）
- `wave_complete.ogg` - 波次完成（胜利音效）
- `level_up.ogg` - 属性提升音效

### 环境音效
- `ambient_wind.ogg` - 背景风声（循环）

## 三、背景音乐（优先级：低）

- `bgm_menu.ogg` - 主菜单音乐（循环）
- `bgm_battle.ogg` - 战斗音乐（循环，节奏感强）
- `bgm_shop.ogg` - 商店音乐（循环，轻松）
- `bgm_victory.ogg` - 胜利音乐（短，10-15秒）
- `bgm_defeat.ogg` - 失败音乐（短，10-15秒）

## 四、音效规格

### 格式要求
- **格式**: OGG Vorbis（推荐）或 WAV
- **采样率**: 44.1kHz
- **比特率**: 128-192 kbps（OGG）
- **声道**: 单声道（音效）/ 立体声（音乐）

### 音量规范
- 音效: -6dB 到 -12dB（避免爆音）
- 音乐: -12dB 到 -18dB（不抢音效）
- 所有音频需要归一化处理

### 时长建议
- 射击音效: 0.1-0.2秒
- 打击音效: 0.2-0.3秒
- UI 音效: 0.1-0.15秒
- 环境音效: 2-5秒（循环）
- 背景音乐: 60-120秒（循环）

## 五、免费资源推荐

### 音效库
- **Freesound.org** - 大量免费音效
- **OpenGameArt.org** - 游戏音效资源
- **Kenney.nl** - 免费游戏资源包（含音效）
- **SFXR/BFXR** - 在线生成 8-bit 音效

### 音乐库
- **Incompetech.com** - Kevin MacLeod 免费音乐
- **FreePD.com** - 公共领域音乐
- **Purple Planet** - 免费背景音乐

## 六、Godot 音频节点配置

### AudioStreamPlayer（全局音效）
```gdscript
var audio_player = AudioStreamPlayer.new()
audio_player.stream = load("res://assets/audio/shoot.ogg")
audio_player.volume_db = -6.0
audio_player.play()
```

### AudioStreamPlayer2D（空间音效）
```gdscript
var audio_player_2d = AudioStreamPlayer2D.new()
audio_player_2d.stream = load("res://assets/audio/enemy_death.ogg")
audio_player_2d.max_distance = 1000.0
audio_player_2d.attenuation = 2.0
audio_player_2d.play()
```

### 音乐循环设置
```
在 Godot 导入设置中:
Loop: Enabled
Loop Offset: 0
```

## 七、音频管理器（建议实现）

创建全局 AudioManager 单例：
- 统一管理音效播放
- 控制音量（主音量、音效、音乐分离）
- 音效池（避免重复创建节点）
- 淡入淡出效果

## 八、MVP 阶段策略

**最小可行方案**：
- 仅添加 3-5 个关键音效（射击、受伤、拾取金币）
- 无背景音乐
- 使用 BFXR 快速生成 8-bit 音效

**完整方案**：
- 所有战斗音效
- 1-2 首背景音乐
- 完整的音频管理系统

---

**创建日期**: 2026-03-03
**状态**: 待实施
