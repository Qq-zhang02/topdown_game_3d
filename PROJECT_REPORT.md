# TopDownGame3D v2.1 — 项目交接文档

> Godot 4.7.1 · 俯视角 3D · 全 GDScript · 2026-07-22

---

## 1. 项目路径

```
F:/godot_stuff/projects/topdown_game_3d-v2/
```

Godot 可执行文件：
```
F:/godot_stuff/install_sites/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe
```

GitHub (私有)：`https://github.com/Qq-zhang02/topdown_game_3d-v2`

---

## 2. 目录结构

```
topdown_game_3d-v2/
├── project.godot              # 项目配置
├── .gitignore                 # 排除 .godot/
├── scenes/
│   ├── main.tscn              # 入口 (Node3D → world_3d.gd)
│   └── player.tscn            # 玩家 (CharacterBody3D → player_3d.gd)
├── scripts/
│   ├── world_3d.gd            # 世界总管：光照/地面/障碍物/边界/玩家/摄像机/小地图/菜单/昼夜/动物
│   ├── player_3d.gd           # 玩家：移动/跳跃/朝向/装备/动画/碰撞/皮肤
│   ├── camera_follow_3d.gd    # 摄像机：跟随 + 右键瞄准偏移
│   ├── animal_spawner.gd      # 动物生成器：随机散布小动物到世界
│   ├── animal_behavior.gd     # 动物行为：随机弹跳 + 被撞翻滚 + 代码推挤
│   ├── day_night_cycle.gd     # 24h 昼夜循环
│   ├── equipment.gd           # 装备 Resource 数据类
│   ├── equipment_manager.gd   # 装备管理器
│   ├── equipment_hud.gd       # 底部装备栏 UI
│   ├── minimap_3d.gd          # 小地图
│   ├── start_screen.gd        # 角色选择界面 + CHARACTERS 表
│   ├── menu_manager.gd        # ESC 暂停菜单（含全屏启动）
│   └── keybind_menu.gd        # 按键设置面板
├── models/
│   ├── survivor/              # 主角模型
│   │   ├── characterMedium.fbx    # 骨架+网格
│   │   ├── animations/
│   │   │   ├── idle.fbx          # 待机
│   │   │   ├── run.fbx           # 奔跑
│   │   │   └── jump.fbx          # 跳跃
│   │   ├── survivorMaleB.png     # 男皮肤
│   │   ├── survivorFemaleA.png   # 女皮肤
│   │   ├── zombieA.png           # 僵尸A皮肤
│   │   └── zombieC.png           # 僵尸C皮肤
│   └── animals/              # 24种动物 (Cube Pets GLB)
│       ├── animal-*.glb ×24
│       └── Textures/colormap.png
└── PROJECT_HANDOFF.md        # 本文档
```

---

## 3. 启动流程

```
world_3d._ready()
  ├── DisplayServer 全屏
  ├── StartScreen (选角色界面)
  │     └── 选皮肤 → 点"开始游戏"
  │           └── started.emit(model_path, skin_path)
  │
  _on_game_started(model_path, skin_path)
  ├── _create_lighting()      → SunLight + MoonLight + WorldEnvironment
  ├── _create_ground()        → 100m×100m 噪声草地 + StaticBody3D
  ├── _create_obstacles()     → 100 个随机方块 (4种材质, 1~4m宽, 1.5~5m高)
  ├── _create_boundary()      → 四面 3m 高墙
  ├── _create_player()        → 实例化 player.tscn, set_model_path/skin_path, 碰撞层1, 加入"player"组
  ├── _create_animals()       → AnimalSpawner: 30只随机动物散布世界
  ├── _create_camera()        → CameraFollow3D (10m高, 52°俯角)
  ├── _create_minimap()       → 220×220 左上角小地图
  ├── _create_equipment_hud() → 底部装备栏
  ├── _create_menu()          → MenuManager + KeybindMenu (全屏启动)
  └── _create_day_night_system() → 24秒一天, time_scale=60
```

---

## 4. 操作

| 按键 | 功能 |
|------|------|
| WASD | 移动 |
| 鼠标 | 朝向 |
| Space | 跳跃 |
| F | 切换装备 (关→手电→火把→关) |
| 鼠标右键(按住) | 瞄准 (摄像机偏移, 移速减半) |
| Esc | 暂停菜单 (继续/重开/主页/按键/退出) |

---

## 5. 碰撞层

| 层 | 对象 | mask |
|----|------|------|
| 1 | 地面、障碍物、边界、玩家 | 玩家mask=1, 障碍物mask=1 |
| 2 | 动物 (RigidBody3D) | mask=1 (只碰撞地面/障碍物) |

**关键**：玩家和动物之间 **没有物理碰撞**，互推完全由 `animal_behavior.gd` 的 `_check_player_push()` 代码驱动。玩家在 `world_3d.gd` 中加入 `"player"` 组供动物检测。

---

## 6. 脚本详解

### 6.1 player_3d.gd — 玩家

```
CharacterBody3D
├── 属性: speed(9.0), jump_velocity(15), gravity(35), vision_range(5)
├── _model_path / _skin_path: 由 world_3d 在 add_child 前设置
├── _create_model(): 加载 FBX → 缩放至1.5m → 应用皮肤 → 关阴影
├── _create_collision(): 基于 AABB.get_center() 生成胶囊碰撞体
├── _setup_animations(): 从动画FBX提取 AnimationPlayer → 加载 idle/run/jump
├── _update_animation(): IDLE/RUN/JUMP 状态机
├── _face_mouse(): 获取鼠标地面坐标 → look_at
├── get_mouse_ground_position(): 射线检测鼠标在地面位置
├── is_aiming(): 检测右键按下
└── _physics_process(): 重力→跳跃→WASD→move_and_slide→朝向→动画
```

### 6.2 camera_follow_3d.gd — 摄像机

```
Camera3D
├── HEIGHT=10.0, TILT_ANGLE=52°
├── 基础位置: 玩家上方10m + 向后偏移(cos52°×10=6.16m)
├── 瞄准模式:
│   ├── 按住右键 → 计算鼠标地面位置 → 偏移量=vision_range × 距离比
│   ├── 速度: 初始5 → 加速18/s → 上限22
│   └── 松开右键 → 匀速20归位
├── look_at 目标随偏移同步移动 (保持视角不变)
└── 偏移仅 XZ 平面 (y=0)
```

### 6.3 animal_spawner.gd — 动物生成器

```
Node (由 world_3d 创建)
├── count=30, min_scale=0.15, max_scale=0.35
├── setup(world_half, obstacle_data, player_pos)
├── spawn_all():
│   ├── 随机位置 → 检测是否与障碍物重叠 (AABB + 6m安全距)
│   ├── 远离玩家5m+
│   └── _spawn_animal(model, pos, scale, rotY)
└── _spawn_animal():
    ├── RigidBody3D: mass=1.0, layer=2, mask=1, damp=0.6
    ├── 加载 GLB → 缩放 → 旋转
    ├── CapsuleShape3D: radius=0.25×scale, height=0.6×scale
    ├── 关阴影
    └── 挂载 AnimalBehavior 脚本 (hop_impulse 1.5~3.0, hop_up 2.5~5.0)
```

### 6.4 animal_behavior.gd — 动物行为

```
Node (挂在每只动物的 RigidBody3D 上)
├── 弹跳: 每1~4s → apply_central_impulse(随机方向×hop_impulse + UP×hop_up)
├── 推挤: _check_player_push(delta) 每帧检测
│   ├── 距离<0.5m → force = mass × push_multiplier(3.0) × 距离比
│   ├── apply_central_force(away×force + UP×force×0.3)
│   └── 进入翻滚状态
├── 翻滚: 解锁 angular_x/z → 随机扭矩 → 0.7s后重锁 → rotation=(0,y_rot,0)
└── 平时: axis_lock_angular_x/z=true (保持头上脚下)
```

### 6.5 world_3d.gd — 世界总管

```
Node3D
├── 常量: WORLD_HALF=50, OBSTACLE_COUNT=100
├── 存储: _obstacle_positions (给小地图), _obstacle_data (给动物生成器)
├── _create_obstacles(): 随机方块 ×100, 记录 position+size 到两个数组
├── _create_animals(): 创建 AnimalSpawner → setup → spawn_all
├── _create_player(): 设置 collision_mask=1, add_to_group("player")
└── _ready(): DisplayServer.window_set_mode(FULLSCREEN) 启动全屏
```

### 6.6 start_screen.gd — 角色选择

```
CanvasLayer (layer=500)
├── CHARACTERS 表: 4条 (男/女幸存者, 僵尸A/C)
├── 信号: started(model_path, skin_path)
├── 左: 3D预览 (SubViewport, 自动缩放适配)
├── 右: 角色网格按钮
├── _apply_preview_skin(): 加载选中皮肤贴到预览模型
└── _layout_ui(): 窗口缩放时重算位置+比例 (REF=1920×1080, scale=0.6~1.6)
```

### 6.7 menu_manager.gd — 暂停菜单

```
CanvasLayer (layer=300)
├── 5按钮: 继续/重开/主页/按键/退出
├── 面板大小 300×330, 居中+比例缩放
├── _input(): ESC 切换暂停
└── _on_restart/_on_home: reload_current_scene()
```

### 6.8 其他脚本

| 脚本 | 功能 |
|------|------|
| `keybind_menu.gd` | 按键设置, 7动作, 持久化 `user://keybinds.cfg` |
| `equipment.gd` | Equipment Resource: id/name/light_type/color/range/offset |
| `equipment_manager.gd` | 装备循环, cycle_next(), get_count() |
| `equipment_hud.gd` | 底部10格装备栏, F键标签, 窗口缩放自适应 |
| `minimap_3d.gd` | CanvasLayer._draw(), 黄点玩家+朝向, 灰点障碍物 |
| `day_night_cycle.gd` | 24秒一天, 太阳绕X轴, 月亮对面, 光色过渡 |

---

## 7. 动物系统当前状态

### 行为
- ✅ 随机弹跳移动 (每1~4秒, 随机方向)
- ✅ 被玩家靠近推挤 (代码驱动, 无物理碰撞)
- ✅ 被撞翻滚 (解锁旋转轴, 随机扭矩)
- ✅ 翻滚后恢复站立 (重锁X/Z轴 + rotation重置)
- ✅ 玩家永不被动物推飞 (无物理双向碰撞, mass=1.0)

### 可调参数 (animal_behavior.gd)
```
hop_impulse=2.0      # 弹跳水平冲量 (生成时随机 1.5~3.0)
hop_up=3.5           # 弹跳垂直冲量 (生成时随机 2.5~5.0)
push_multiplier=3.0  # 推力倍数 (force = mass × this × 距离比)
min_hop_interval=1.0
max_hop_interval=4.0
TUMBLE_TIME=0.7      # 翻滚持续时间
PUSH_DISTANCE=0.5    # 推挤检测距离
```

### 可调参数 (animal_spawner.gd)
```
count=30
min_scale=0.15, max_scale=0.35
spawn_margin=6.0     # 离障碍物安全距离
```

---

## 8. 已知问题 / 注意事项

1. **FBX 动画**：需要 FBX2glTF (已安装在 `%APPDATA%\Godot\editor_data\`)。当前动画通过代码从动画 FBX 提取 AnimationPlayer 实现，可能不稳定。
2. **模型朝向**：`player_3d.gd` 第58行 `_model_root.rotation.y = PI`，针对幸存者模型可能需要调整。
3. **class_name 引用**：Godot 4.7 不建议用其他脚本的 class_name 做类型标注，用 `load()` 替代。
4. **GDScript 类型推断**：从 `Node3D` 调用的动态方法（如 `target.get_mouse_ground_position()`）需要用显式类型标注 `: Vector3 =`。
5. **AABB.position**：Godot 4 中是 minimum corner，不是中心。用 `aabb.position + aabb.size * 0.5` 或 `aabb.get_center()`。
6. **UI 缩放**：所有 UI 以 1920×1080 为参考分辨率，scale 范围 0.6~1.6。
7. **全屏**：在 `world_3d.gd` `_ready()` 中代码设置，非 project.godot 设置。
8. **Git**：`.gitignore` 排除 `.godot/`。提交用 `git push --force` 覆盖 v2.1 标签。

---

## 9. Git 操作

```bash
# 提交
cd F:/godot_stuff/projects/topdown_game_3d-v2
git add -A
git commit -m "描述"
git push --force
git tag -d v2.1 && git tag -a v2.1 -m "v2.1" && git push --tags --force

# 回退
git checkout v2.1 -- .
```

---

## 10. 开发提示

- 修改 `.gd` 文件后，Godot 编辑器会自动检测并重载 (4.7)
- `get_tree().root.size_changed` 是 UI 自适应缩放的关键信号
- `DisplayServer.window_set_mode()` 是控制全屏/窗口的 API
- 角色朝向由 `_face_mouse()` 每帧调用 `look_at` 实现
- 动物使用 `get_nodes_in_group("player")` 查找玩家
