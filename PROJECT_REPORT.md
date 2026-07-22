# TopDownGame3D — 项目说明书

> Godot 4.7.1 · 俯视角 3D · 纯 GDScript 代码构建 · 2026-07

---

## 一、项目概览

| 属性 | 值 |
|------|-----|
| **路径** | `F:/godot_stuff/projects/topdown_game_3d/` |
| **引擎** | Godot 4.7.1 |
| **渲染** | Forward+（3D） |
| **分辨率** | 1280×720 |
| **语言** | GDScript |
| **场景** | 2 个 .tscn（main + player），其余全部代码生成 |
| **模型** | Kenney Cube Pets（24 动物）+ Kenney Blocky Characters（18 方块人）= 42 角色 |
| **Godot 可执行文件** | `F:/godot_stuff/install_sites/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe` |

---

## 二、目录结构

```
topdown_game_3d/
├── project.godot                     # 项目配置 + 输入映射（7 个动作）
├── PROJECT_REPORT.md                 # 📋 本文档
├── scenes/
│   ├── main.tscn                     # 入口（Node3D + world_3d.gd）
│   └── player.tscn                   # 玩家（CharacterBody3D + player_3d.gd）
├── scripts/
│   ├── world_3d.gd                   # 🌍 世界总调度
│   ├── player_3d.gd                  # 🎮 玩家：移动/跳跃/朝向/装备
│   ├── camera_follow_3d.gd           # 📷 俯视角跟随摄像机
│   ├── day_night_cycle.gd            # 🌞🌙 24h 昼夜循环
│   ├── equipment.gd                  # 🔦 装备数据类（Resource）
│   ├── equipment_manager.gd          # 🔄 装备管理器（装备/卸下/切换）
│   ├── equipment_hud.gd              # 🖥️ 底部装备栏（显示 equipped=true 项）
│   ├── minimap_3d.gd                 # 🗺️ 左上角小地图
│   ├── start_screen.gd               # 🎬 角色选择界面 + CHARACTERS 数据表
│   ├── menu_manager.gd               # ⏸️ ESC 暂停菜单
│   └── keybind_menu.gd               # ⌨️ 按键设置面板
└── models/
    ├── animals/                       # 24 个动物 GLB
    │   ├── animal-*.glb
    │   └── Textures/colormap.png     # 共用贴图
    └── blocky/                        # 18 个方块人 GLB
        ├── character-*.glb
        └── Textures/texture-*.png    # 各角色独立贴图
```

---

## 三、启动流程

```
F5 运行
  │
  world_3d._ready()
  ├── StartScreen                         ← 角色选择界面
  │     │
  │     │  选角色 + 点「开始游戏」
  │     │
  │     started.emit(model_path)
  │
  _on_game_started(model_path)
  ├── _create_lighting()                  ← 太阳光/月光/环境
  ├── _create_ground()                    ← 100m 噪声纹理草地
  ├── _create_obstacles()                 ← 100 个方块（4 种材质）
  ├── _create_boundary()                  ← 四面墙
  ├── _create_player(model_path)          ← 加载 GLB → 缩放 → 碰撞体
  ├── _create_camera(player)              ← Camera3D 俯视跟随
  ├── _create_minimap(player)             ← 左上角 2D 小地图
  ├── _create_equipment_hud(player)       ← 底部装备栏
  ├── _create_menu()                      ← ESC 暂停 + 按键设置
  └── _create_day_night_system()          ← 24 秒一个昼夜
```

---

## 四、操作说明

| 按键 | 功能 | 默认键 |
|------|------|--------|
| 移动 | WASD 四方向 | W/A/S/D |
| 朝向 | 鼠标位置 | — |
| 跳跃 | 仅限地面 | Space |
| 切换装备 | 关→手电→火把→关 | F |
| 瞄准 | 摄像机跟随鼠标偏移 | 鼠标右键（按住） |
| 暂停 | 菜单 | Esc |

按键可在游戏中修改：**Esc → 按键设置**，配置持久化到 `user://keybinds.cfg`。

---

## 五、核心系统

### 5.1 角色数据表

位置：`start_screen.gd` 第 7~52 行

```gdscript
const CHARACTERS := [
    {id="fox",   name="🦊 狐狸", path="res://models/animals/animal-fox.glb"},
    {id="char_a",name="🧑 角色 A",path="res://models/blocky/character-a.glb"},
    // 共 42 个
]
```

| 字段 | 说明 |
|------|------|
| `id` | 唯一标识 |
| `name` | 按钮显示文字（支持 emoji） |
| `path` | 模型 GLB 路径 |

**加新角色**：放 GLB 到 models 子目录 → 表里加一行。默认选中 = `CHARACTERS[12]`（狐狸）。

### 5.2 装备系统

```
Equipment (Resource)
├── id, display_name       # 标识/显示名
├── equipped: bool         # 是否在循环中（决定装备栏可见+F键可达）
├── light_type: SPOT/OMNI  # 光源类型
├── light_color/energy     # 颜色/亮度
├── spot_range/omni_range  # 射程
└── position_offset        # 相对玩家偏移

EquipmentManager (Node)
├── equipment_list          # 全部装备
├── _current_index          # 当前装备索引（-1=关）
├── cycle_next()            # 只遍历 equipped=true 的项
├── get_count()             # equipped 项数量
├── get_active_slot()       # 当前在装备栏的槽位
└── get_name_at(slot)       # 第 slot 个已装备项的名字
```

**已有装备**：手电筒（SpotLight 50m）/ 火把（OmniLight 12m），默认都 `equipped=true`。

**加新装备**：在 `player_3d.gd` 里加工厂函数 + `add_equipment()`，设 `equipped=true` 即可出现在循环中。

### 5.3 昼夜循环

| 参数 | 值 |
|------|-----|
| 速度 | 1 真秒 = 60 游分（24 秒一天） |
| 起始 | 6:00 AM |
| 太阳 | 绕 X 轴，6:00=地平线, 12:00=天顶 |
| 月亮 | 太阳对面（+180°），蓝白柔光 |
| 过渡 | 黎明/黄昏暖橙 ↔ 正午白 ↔ 夜蓝 |

### 5.4 摄像机

- Camera3D 透视投影
- 玩家上方 10m + 向后倾斜偏移（~52° 俯角），可看到角色正面
- 看向角色上半身（y ≈ 1.0m），不再只看到脑袋顶
- **瞄准模式**：按住鼠标右键 → 摄像机随鼠标方向偏移，鼠标离角色越远偏移越多
- 最大偏移 = `vision_range`（默认 5.0m，即角色「视力」属性）
- 松开右键平滑归位（`AIM_SMOOTH = 6.0`）

### 5.5 小地图

- CanvasLayer → Control._draw()
- 3D 坐标 XZ → 2D 小地图 XY
- 显示：玩家（黄点+朝向三角）、障碍物（灰点）、边界

### 5.6 键位系统

- 位置：`keybind_menu.gd`
- 7 个动作（移动×4 + 切换装备 + 跳跃 + 暂停），均支持自定义键位
- 每个动作配有 `default` 硬编码默认键，重置时直接写回
- 保存到 `user://keybinds.cfg`，启动时自动加载
- 改键后发 `bindings_changed` 信号 → 装备栏标签实时刷新
- ESC 保护：只允许绑定到「暂停」

### 5.7 UI 层级

| 组件 | layer | 说明 |
|------|-------|------|
| StartScreen | 500 | 角色选择（左 3D 预览 + 右 7 列网格） |
| KeybindMenu | 400 | 按键设置面板 |
| MenuManager | 300 | ESC 暂停：继续/重开/主页/按键/退出 |
| Minimap | 100 | 左上角 |
| EquipmentHUD | 50 | 底部装备栏（F 提示 + 10 格） |

---

## 六、玩家脚本 (player_3d.gd)

| 变量 | 类型 | 说明 |
|------|------|------|
| `_model_path` | String | 当前模型路径，可通过 `set_model_path()` 在实例化前设 |
| `_model_root` | Node3D | 加载的 GLB 场景根节点 |
| `_equipment_mgr` | Node | EquipmentManager 引用 |
| `speed` | @export float (9.0) | 移动速度 |
| `jump_velocity` | @export float (15.0) | 跳跃力度 |
| `gravity` | @export float (35.0) | 重力 |
| `vision_range` | @export float (5.0) | 视力属性，瞄准时摄像机最大偏移 |

**关键方法**：
- `set_model_path(path)` — 选角界面调用，必须在 `add_child` 前设置
- `_create_model()` — 加载 GLB、自动缩放至 1.5m、旋转 PI 修正朝向、关自身阴影
- `_create_collision()` — 基于包围盒自动生成胶囊碰撞体
- `_physics_process()` — 重力→跳跃→WASD→move_and_slide→look_at

---

## 七、输入映射 (project.godot)

| 动作名 | 默认键 | physical_keycode |
|--------|--------|------------------|
| `move_up` | W | 87 |
| `move_down` | S | 83 |
| `move_left` | A | 65 |
| `move_right` | D | 68 |
| `cycle_equipment` | F | 70 |
| `jump` | Space | 32 |
| `pause` | Esc | 4194305 |

---

## 八、世界参数 (world_3d.gd)

| 常量 | 值 | 说明 |
|------|-----|------|
| `WORLD_HALF` | 50.0 | 半边长，总世界 100×100m |
| `OBSTACLE_COUNT` | 100 | 障碍物数量 |
| `MINIMAP_SIZE` | (220, 220) | 小地图像素尺寸 |

---

## 九、⚠️ 开发注意事项（必读）

### 9.1 class_name 跨文件引用

Godot 4.7 脚本解析顺序不确定，**禁止**用其他脚本的 `class_name` 作为类型标注。始终用 `preload()/load()`：

```gdscript
# ❌
var mgr: EquipmentManager = ...

# ✅
const EQ = preload("res://scripts/equipment.gd")
var eq = EQ.new()
eq.set("id", "flashlight")  # 用 .set() 而非 .属性名
```

### 9.2 修改代码需重启 Godot

编辑器缓存脚本，外部修改不自动重载。每次改脚本 → 关闭 Godot → 重新打开 → F5。（这一条存疑，会自动重载）

### 9.3 CanvasLayer 子节点尺寸

CanvasLayer 不是 Control，`PRESET_FULL_RECT` 锚点无效。UI 尺寸必须用 `get_viewport().get_visible_rect().size` 手动获取。

### 9.4 模型导入

- GLB 贴图是相对路径，必须保持 `GLB` 和 `Textures/` 的相对关系
- 贴图变动后删 `.godot/` 文件夹重建导入缓存
- 动物共用 `colormap.png`，方块人各用 `texture-*.png`

### 9.5 模型预览

- SubViewport 内：`look_at_from_position()` 替代 `look_at()`
- 模型必须先 `add_child()` 入树再用 `global_transform` 算包围盒
- 初始角度 `PI/4`（45°正面），自转方向顺时针（`-= delta * 1.2`）

### 9.6 键位系统

- `InputEventKey` 必须同时设 `keycode` 和 `physical_keycode`，Godot 靠后者检测
- 改动作名后需删 `user://keybinds.cfg`，不然旧名条目残留

---

## 十、常见修改速查

| 需求 | 位置 |
|------|------|
| 换默认角色 | `player_3d.gd` `_model_path` 变量 |
| 加新角色 | GLB 放 models → `start_screen.gd` CHARACTERS 表加一行 |
| 改角色名/emoji | CHARACTERS 表 `name` 字段 |
| 删角色 | CHARACTERS 表删该行 |
| 改移动速度 | `player_3d.gd` `@export var speed` |
| 改跳跃 | `player_3d.gd` `jump_velocity` / `gravity` |
| 加新装备 | `player_3d.gd` 工厂函数 + `add_equipment()` + `equipped=true/false` |
| 改昼夜速度 | `world_3d.gd` `_create_day_night_system()` 的 `time_scale` |
| 改障碍物/世界大小 | `world_3d.gd` `OBSTACLE_COUNT` / `WORLD_HALF` |
| 改摄像机高度 | `camera_follow_3d.gd` `HEIGHT` |
| 改预览旋转速度 | `start_screen.gd` `_process` 的 `delta * 1.2` |
| 加新键位动作 | `keybind_menu.gd` ACTIONS 数组加一行 |
| 导出游戏 | 编辑器：管理导出模板 → 下载 x86_64 → 项目→导出→Windows |
| 删键位配置 | `%APPDATA%\Godot\app_userdata\TopDownGame3D\keybinds.cfg` |
| 导出模板路径 | `%APPDATA%\Godot\export_templates\4.7.1.stable\` |

---

## 十一、修复记录

### 11.1 角色碰撞体偏移修复 (2026-07-21)

**问题**：胶囊碰撞体与角色模型不对齐——碰撞体正面超出模型过多，背面缩在模型内部。

**原因**：`player_3d.gd` 第 102 行 `col.position = Vector3(0, aabb.size.y * 0.45, 0) + aabb.position` 中，`AABB.position` 在 Godot 4 中是最小角（minimum corner），不是几何中心。X、Z 轴直接使用了最小角坐标，导致碰撞体偏移了半个模型的宽度/深度。

**修复**：改为 `col.position = to_local(aabb.position + aabb.size * 0.5)`，使用 AABB 几何中心 + `to_local()` 确保坐标正确转换到 CharacterBody3D 本地空间。

### 11.2 摄像机调低 + 瞄准系统 (2026-07-22)

**改动**：
- 摄像机高度 35m → 10m，俯角 70° → 52°，看向角色上半身而非地面
- 新增瞄准模式：按住鼠标右键 → 摄像机随鼠标方向水平偏移
- 鼠标离角色越远偏移越多，最大偏移 = `vision_range`（默认 5.0m）
- 松开右键平滑归位
- `vision_range` 为玩家「视力」属性（`@export`，后续装备可加成）
