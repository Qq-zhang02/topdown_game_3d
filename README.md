# TopDownGame3D v2.2

> Godot 4.7.1 · 俯视角 3D · 全 GDScript · 2026-07-22

---

## 1. 项目路径

```
F:/godot_stuff/projects/topdown_game_3d-v2/
```

GitHub (公开)：`https://github.com/Qq-zhang02/topdown_game_3d-v2`

---

## 2. 目录结构

```
topdown_game_3d-v2/
├── project.godot
├── .gitignore
├── scenes/
│   ├── main.tscn              # 入口 (Node3D → world_3d.gd)
│   └── player.tscn            # 玩家 (CharacterBody3D → player_3d.gd)
├── scripts/
│   ├── world_3d.gd            # 世界总管：光照/地面/障碍物/边界/玩家/摄像机/小地图/菜单/昼夜/动物
│   ├── player_3d.gd           # 玩家：移动/跳跃/朝向/装备/动画/碰撞
│   ├── camera_follow_3d.gd    # 摄像机：跟随 + 右键瞄准偏移
│   ├── animal_spawner.gd      # 动物生成器：随机散布 RigidBody3D 动物
│   ├── animal_behavior.gd     # 动物行为：随机弹跳 + 玩家推挤 + 边界安全
│   ├── day_night_cycle.gd     # 24h 昼夜循环
│   ├── equipment.gd           # 装备 Resource 类
│   ├── equipment_manager.gd   # 装备管理器
│   ├── equipment_hud.gd       # 底部装备栏 UI
│   ├── minimap_3d.gd          # 小地图
│   ├── start_screen.gd        # 角色选择界面 + 动画预览
│   ├── menu_manager.gd        # ESC 暂停菜单
│   └── keybind_menu.gd        # 按键设置面板
├── models/
│   ├── character/             # 主角模型 (Kenney Mini-Forest)
│   │   ├── character-archer.glb   # 弓箭手 (31个内嵌动画)
│   │   └── colormap.png           # 纹理
│   └── animals/               # 24种 Cube Pets GLB
│       ├── animal-*.glb x24
│       └── Textures/colormap.png
└── README.md
```

---

## 3. 启动流程

```
world_3d._ready()
  ├── DisplayServer 全屏
  ├── StartScreen (角色选择界面 + 动画预览按钮)
  │     └── 点"开始游戏" → started.emit(model_path, skin_path)
  │
  _on_game_started(model_path, skin_path)
  ├── _create_lighting()      → SunLight + MoonLight + WorldEnvironment
  ├── _create_ground()        → 100mx100m 噪声草地 + StaticBody3D
  ├── _create_obstacles()     → 100 个随机方块 (4种材质)
  ├── _create_boundary()      → 四面 3m 高墙
  ├── _create_player()        → 实例化 player.tscn, 碰撞层1, "player"组
  ├── _create_animals()       → AnimalSpawner: 30只随机动物
  ├── _create_camera()        → CameraFollow3D
  ├── _create_minimap()       → 220x220 小地图
  ├── _create_equipment_hud() → 底部装备栏
  ├── _create_menu()          → MenuManager + KeybindMenu
  └── _create_day_night_system() → 昼夜循环
```

---

## 4. 操作

| 按键 | 功能 |
|------|------|
| WASD | 移动 |
| 鼠标 | 朝向 |
| Space | 跳跃 |
| Q | 切换装备 (关→手电→火把→关) |
| 鼠标右键(按住) | 瞄准 (摄像机偏移, 移速减半) |
| Esc | 暂停菜单 |

---

## 5. 碰撞层

| 层 | 对象 | mask |
|----|------|------|
| 1 | 地面、障碍物、边界、玩家 | 玩家mask=1 |
| 2 | 动物 (RigidBody3D, continuous_cd=true) | mask=1 (地面/障碍物) |

玩家和动物之间**没有物理碰撞**，推挤由 `animal_behavior.gd` 代码驱动。

---

## 6. 脚本详解

### 6.1 player_3d.gd — 玩家

```
CharacterBody3D
├── speed=9.0, jump_velocity=15, gravity=35
├── 模型: character-archer.glb → 缩放至1.5m → colormap.png
├── 动画: GLB内嵌31个动画, 自动映射 idle/walk/jump
├── move_and_slide() + look_at鼠标位置
└── 装备: 手电筒(SpotLight) + 火把(OmniLight), Q键切换
```

### 6.2 animal_spawner.gd — 动物生成器

```
AnimalSpawner (Node)
├── count=30, min_scale=0.4, max_scale=0.5
├── 随机位置 → 避开障碍物 + 远离玩家5m
└── RigidBody3D: mass=1.0, layer=2, mask=1, continuous_cd=true
```

### 6.3 animal_behavior.gd — 动物行为

```
AnimalBehavior (Node, 每只动物一个)
├── 弹跳: 每1~4s → 先旋转朝向(0.2s) → apply_central_impulse
├── 推挤:
│   ├── 冷却0.25s, 距离<0.6m触发
│   ├── 力 = clamp(min + 玩家速度 x ratio, 0.5, 1.5)
│   └── apply_central_impulse (一次性, 不叠加)
├── 安全: 边界夹持 + 速度上限20m/s
└── 无翻滚 (angular_x/z 永久锁定)
```

### 6.4 start_screen.gd — 角色选择

```
CanvasLayer (layer=500)
├── 角色: 弓箭手 (唯一)
├── 左: 3D预览旋转展示
├── 动画预览: 31个按钮 (7列x5行), 点击播放
└── 自适应缩放 (REF=1920x1080)
```

---

## 7. GLB 内嵌动画 (31个)

| 类别 | 动画名 |
|------|--------|
| 基础 | idle, walk, sprint, jump, fall, die, crouch |
| 姿态 | static, sit, drive, pick-up |
| 攻击 | attack-melee-left/right, attack-kick-left/right |
| 持武器 | holding-both/left/right (+shoot版) |
| 交互 | interact-left/right, emote-no/yes |
| 轮椅 | wheelchair-sit/look/move-* (7个) |

---

## 8. 注意事项

- **AABB.position**: Godot 4 中是 minimum corner，用 `position + size*0.5` 获取中心
- **UI 缩放**: 1920x1080 参考，scale 0.6~1.6
- **全屏**: 代码设置，非 project.godot
- **GLB 动画**: 角色动画来自模型内嵌
- **continuous_cd**: 动物 RigidBody3D 开启防穿透
