# TopDownGame3D v3.6.1

> Godot 4.7.1 · 俯视角 3D · 全 GDScript · 2026-08-18

---

## 0. 更新记录

### v3.6.1

- 世界生成边界与类圆形地形轮廓一致：障碍物、资源、动物重生、建造占地均限制在地形边界内。
- 岩浆越界判定改为真实地形碰撞射线，修复某些边界不会对玩家造成伤害的问题。
- 动物可被玩家击退到岩浆中：掉入岩浆后以 2m/s 缓慢下沉，播放 2 秒挣扎动画（随机 `run` / `gesture-negative`），随后消失。
- 动物白天的一次性随机动画改为连续播放 2~3 次；`idle` 持续循环播放。
- 统一动物边界判定：白天到边界会自行选择安全方向离开；夜间追击到边界会停止 run，原地等待或沿边界绕行，修复边界持续原地 run / 卡死问题。

### v3.6.0

- 小动物接入 GLB 内置动画系统（24 种模型共用同一套动画：idle / walk / run / dance / eat / gesture / static）。
- 白天：随机播放内置动画，普通移动使用 walk 动画散步。
- 夜间狂暴：发现玩家后使用 run 动画追击，追到近距离恢复原跳跃攻击。
- 移动前先原地转向移动方向（动物模型前方为 +Z），转向完成后才移动。
- 锁定动物 RigidBody 全部角轴，避免移动/碰撞时身体自转导致侧着走或乱转。
- 跳跃攻击后原地停留 1 秒（`post_attack_pause` 可配置），再继续追击。

---

## 1. 项目路径

```
F:/godot_stuff/projects/topdown_game_3d-v3/
```

GitHub (私密)：`https://github.com/Qq-zhang02/topdown_game_3d`

---

## 2. 目录结构

```
topdown_game_3d-v3/
├── project.godot
├── scenes/
│   ├── main.tscn              # ★ 入口：地形/光照/环境可视化摆放 (Node3D → world_3d.gd)
│   ├── player.tscn            # ★ 玩家：模型占位/碰撞/灯光/子系统节点编辑器摆放
│   └── prefabs/               # ★ 实体预制体（编辑器可视化编辑外观）
│       ├── tree.tscn / rock.tscn          # 资源节点（外观可编辑，位置代码随机）
│       ├── pickup.tscn                    # 掉落物
│       ├── obstacle.tscn                  # 障碍物（单位尺寸，运行时缩放）
│       └── building_campfire / building_foundation / building_wooden_wall.tscn
├── data/                      # ★ 数据驱动内容：新增物品/建筑 = 加 .tres，零代码
│   ├── items/                 # 物品（ItemDB 自动扫描，按 id 取用）
│   │   ├── wood.tres / stone.tres / meat.tres
│   │   ├── weapons/sword_wood.tres
│   │   └── equipment/flashlight.tres / torch.tres
│   └── buildings/             # 建筑配方（BuildController 自动扫描）
│       ├── campfire.tres / wooden_wall.tres / foundation.tres
├── scripts/
│   ├── core/
│   │   ├── item_data.gd       # 物品基类 Resource（ItemType: MATERIAL/EQUIPMENT/WEAPON）
│   │   ├── item_stack.gd      # 背包格子 {item, count}
│   │   └── item_db.gd         # 物品数据库：扫描 data/items/，ItemDB.get_item(id)
│   ├── inventory/
│   │   ├── inventory.gd       # 背包数据层：32格，增删/堆叠/消耗，changed 信号
│   │   ├── inventory_ui.gd    # 背包界面：8x4，Tab 开关，拖拽整理，右键菜单（装备/卸下/使用）
│   │   └── inventory_slot.gd  # 背包格子（拖拽 + 右键菜单）
│   ├── combat/
│   │   ├── health.gd          # 通用血量组件（受击红闪+溅射粒子，自动覆盖所有挂载者）
│   │   ├── melee_controller.gd# 近战：左键扇形判定，伤害取自当前 WeaponData
│   │   ├── hazard.gd          # ★ 危险区组件：触碰扣血+击退（篝火/地刺等）
│   │   └── pickup.gd          # 掉落物：上抛弹跳→滑行→可拾取，射线贴合地形，飞向角色消失
│   ├── building/
│   │   ├── building_data.gd   # 建筑定义：尺寸/颜色/材料消耗/发光
│   │   ├── build_controller.gd# 建造模式：幽灵预览(绿/红)+网格吸附+R旋转，贴合地形高度
│   │   └── build_menu_ui.gd   # 建造菜单：配方列表，材料不足置灰
│   ├── world/
│   │   ├── lava.gd            # 岩浆：滚动熔岩表面，越界落入岩浆持续掉血
│   │   ├── resource_node.gd   # 可采集资源：树(掉木材)/石头(掉石头)
│   │   └── death_screen.gd    # 死亡界面 → 回开始界面
│   ├── items/
│   │   └── weapon_data.gd     # 近战武器数据（继承 ItemData）
│   ├── vfx/
│   │   └── thrust_beam_vfx.gd # 突刺光束 VFX：光束+溅射粒子+尖端爆开（0.2s 时序）
│   ├── world_3d.gd            # 世界总管（占地登记/建造放置/地形加载/各系统组装）
│   ├── player_3d.gd           # 玩家：移动/朝向(反应速度阻尼)/装备/血量/背包/近战/动画
│   ├── equipment.gd           # 光源装备（继承 ItemData：手电筒/火把）
│   ├── equipment_manager.gd   # 装备管理器：功能装备(F)/武器(Q)/消耗品(1/2/3) 三区管理，冷却系统
│   ├── equipment_hud.gd       # 底部装备栏：三区布局 + 冷却覆盖动画
│   ├── camera_follow_3d.gd    # 摄像机：位置/角度偏差驱动追踪 + 瞄准偏移
│   ├── minimap_3d.gd          # 小地图（左上角 220×220，障碍物+动物渲染）
│   ├── day_night_cycle.gd     # ★ 昼夜循环：day_progress 归一化进度，seconds_per_day 单点配置
│   ├── animal_spawner.gd      # 动物生成（+血量/掉落生肉）
│   ├── animal_behavior.gd     # 动物行为（白天随机动画+walk散步/夜间狂暴run追击+跳脸攻击/玩家推挤）
│   ├── save_manager.gd        # ★ 存档管理器：5槽位，JSON读写，可自定义路径
│   ├── save_select_screen.gd  # ★ 存档选择界面：3D预览+动画预览+新建/进入/删除
│   ├── start_screen.gd / menu_manager.gd / keybind_menu.gd / time_display.gd
├── shaders/
│   └── thrust_beam.gdshader   # 突刺光束着色器（前缘生长+噪声流动+Fresnel淡出）
└── models/
    ├── landscape/             # ★ 地形模型 + 贴图 + Blender 源文件
    │   ├── 地形.glb / 地形.blend
    │   └── 地形_*_2K.jpg/png（COL 漫反射 / NRM 法线 / REFL+GLOSS 反射光泽）
    ├── character/             # 角色模型 + colormap.png 皮肤
    ├── animals/               # 24 种动物 GLB + Textures/colormap.png
    └── vfx/ThrustBeam.glb     # 突刺光束模型（锥形能量柱）
```

---

## 3. 启动流程

```
world_3d._ready()
  → SaveSelectScreen（存档选择：5槽位）
      ├─ 空槽位「新建」→ StartScreen（角色选择）→ 新游戏 → 自动存档
      └─ 已有存档「进入」→ 加载世界状态 → 直接进入游戏
  → _on_game_started()
      ├── 光照 / 地面 / 障碍物（登记占地）
      ├── _create_lava()           → 岩浆（边界，落入岩浆掉血）
      ├── _create_player()          → 玩家（含血量/背包/近战/初始物资：木剑+木材12+石头8）
      ├── _create_resource_nodes()  → 25树 + 15石头（可采集）
      ├── 动物 / 摄像机 / 小地图 / 装备栏
      ├── _create_inventory_ui()    → 背包（Tab）
      ├── _create_build_system()    → 建造（B）
      ├── _create_death_screen()    → 死亡界面
      ├── 菜单 / 昼夜 / 时间显示 / 血条 HUD / 受伤反馈
      └── 初始存档 + 启动自动存档定时器
```

---

## 4. 操作

| 按键 | 功能 |
|------|------|
| WASD / 鼠标 / Space | 移动 / 朝向 / 跳跃 |
| **鼠标左键** | 近战攻击（手持武器用武器参数，否则拳头） |
| **F** | 切换功能装备（手电筒→火把→关） |
| **Q** | 切换武器（木剑→关） |
| **1 / 2 / 3** | 使用对应消耗品栏位物品（8 秒冷却） |
| **Tab** | 背包（拖拽整理，右键物品 → 装备 / 卸下 / 使用） |
| **B** | 建造菜单 → 选配方 → 幽灵预览 → 左键放置 |
| **R** | 建造时旋转 90° |
| 右键(按住) | **瞄准**（移速降至1/4 + 摄像机平滑偏移到鼠标指向处）；建造中点右键取消 |
| Esc | 暂停菜单（继续/保存/重新开始/返回/按键/退出） |

---

## 5. 玩家属性

**文件：** `scripts/player_3d.gd`

玩家基础属性在脚本顶部 `@export` 定义：

| 属性 | 默认值 | 说明 |
|------|--------|------|
| `speed` | 4.0 | 移动速度（m/s） |
| `gravity` | 35.0 | 自定义重力（高于默认） |
| `jump_velocity` | 15.0 | 跳跃初速度 |
| `rotation_lag` | 0.0 | 转向迟滞（武器可加，最高 0.95） |
| `vision_range` | 6.0 | 视力距离，瞄准时摄像机最大偏移量 |

**玩家碰撞体：** `scenes/player.tscn` 中的 `CollisionShape3D`（默认 `CapsuleShape3D` radius=0.4, height=1.6）。**场景优先**：场景中已配置的碰撞体完全采用编辑器里的形状/位置（所见即所得）；仅当场景缺失碰撞节点时才回退到基于模型 AABB 自动计算。

### 瞄准减速

按住右键瞄准时，移动速度 **减弱**（×0.25）：

```gdscript
var current_speed: float = speed * 0.25 if is_aiming() else speed
```

### 摄像机系统

**文件：** `scripts/camera_follow_3d.gd`

三套追踪，偏差驱动，无上限，体感无突变：

**位置追踪**（松开右键时）
- 摄像头位置偏离人物时触发
- `速度 = POS_MIN_SPEED(0.1) + 距离 × POS_SPEED_FACTOR(2.0)`，越远越快

**角度追踪**（松开右键时）
- 摄像头未对准人物时触发，look_at 限幅 ±4°
- `旋转速度 = LOOK_MIN_SPEED(0.2°/s) + 角度差 × LOOK_SPEED_FACTOR(1.0)`
- 俯角与偏航分别独立计算，同样'偏离越大追越快'

**瞄准**（按住右键时）
- 位置追踪和角度追踪 **关闭**
- 角度 **冻结** 为按下瞬间的值，瞄准期间不变
- 位置向鼠标方向 **匀速偏移**（`AIM_SPEED` = 8m/s）
- 松开后 `_aim_offset` 匀速归零（`AIM_RETURN_SPEED` = 10m/s），恢复正常追踪

| 参数 | 值 | 说明 |
|------|-----|------|
| `HEIGHT` | 10.0 | 摄像机距地面高度 |
| `TILT_ANGLE` | 52° | 默认俯角 |
| `FOV` | 60° | 透视投影 |
| `POS_MIN_SPEED` | 0.1 | 位置最小追速（m/s） |
| `POS_SPEED_FACTOR` | 1.0 | 位置追速系数（m/s/m） |
| `LOOK_ANGLE_RANGE` | 4° | 角度最大偏离 |
| `LOOK_MIN_SPEED` | 0.2°/s | 角度最小旋转速度 |
| `LOOK_SPEED_FACTOR` | 1.0 | 角度转速系数（°/s/°） |
| `AIM_SPEED` | 8.0 | 瞄准偏移速度（m/s） |
| `AIM_RETURN_SPEED` | 10.0 | 松开右键归位速度（m/s） |

---

## 6. 核心设计（扩展性）

**一切皆数据，新增内容不改代码：**

- **新物品/材料** → `data/items/` 加 .tres（ItemData），ItemDB 自动收录
  
  **ItemData 属性：** `id`、`display_name`、`description`、`item_type`（MATERIAL/EQUIPMENT/WEAPON）、`max_stack`（默认 99）、`heal_amount`（>0 表示可食用）、`ui_color`（背包底色）
- **新武器** → `data/items/weapons/` 加 .tres（WeaponData：伤害/范围/角度/冷却/击退）
- **新建筑** → `data/buildings/` 加 .tres（BuildingData：尺寸/颜色/成本/发光），建造菜单自动出现
- **新的可攻击对象** → 挂 `health.gd`（命名 "Health"）+ 加入 `"damageable"` 组，近战即可命中
- **新光源装备** → 代码里 new Equipment（参考 player_3d.gd `_make_torch`）
- **新掉落物** → `Pickup.spawn(parent, item_res, amount, pos)` 自动处理掉落动画 + 拾取飞行，所有物品统一进背包
- **受击反馈** → 任何挂载 `health.gd` 的实体自动获得：模型闪红 0.3s + 彩色溅射粒子。粒子颜色通过 `set_particle_color()` 设置，默认白色

**背包：** 32 格（8×4 网格），`Inventory.add_item()` 自动堆叠/填空格子，放不下返回剩余数量。物品装备后在背包中**金色高亮**标记，装备/卸下不改变背包内容。

**装备管理器：** 分为三个独立分区——**功能装备**（F 切换，存放手电筒/火把等光源）、**武器**（Q 切换，存放木剑等近战武器）、**消耗品**（3 个快捷栏位，1/2/3 即时使用，8s 冷却）。装备管理器和背包之间通过 `item_id` 引用而非持有副本，物品唯一存放在背包中。

**信号解耦：** `health.died` / `inventory.changed` / `build_menu.recipe_selected`，系统间不直接引用。

**占地管理：** 世界维护 `_occupied: Array[AABB]`（障碍物/资源/建筑），
`is_area_free(center, half)` 统一做建造合法性校验；资源被采完自动释放占地。

### 建筑发光参数

**文件：** `scripts/building/building_data.gd`

建筑（如篝火）可配置发光属性：

| 属性 | 类型 | 说明 |
|------|------|------|
| `emits_light` | bool | 是否发光 |
| `light_color` | Color | 光颜色（篝火默认暖橙） |
| `light_energy` | float | 光强度（默认 3.0） |
| `light_range` | float | 光照范围（默认 8m） |
| `light_attenuation` | float | 衰减（默认 1.0） |
| `light_shadow_enabled` | bool | 灯光是否投阴影 |

发光建筑放置时自动添加 OmniLight3D 子节点，位置在建筑顶部以上 0.6m。光源参数以 `.tres` 为准，放置时覆盖预制体内的灯光值（灯光位置仍在 `.tscn` 预制体内）。

### 危险区（触碰扣血 + 击退，v3.5.1+）

**文件：** `scripts/combat/hazard.gd`（`class_name Hazard`，基于 Area3D 的可复用组件）

建筑可通过 `BuildingData` 配置为危险区（如篝火），玩家触碰后扣血并击退：

| 属性 | 类型 | 说明 |
|------|------|------|
| `hazard_damage` | float | 每次扣血量（>0 启用危险区） |
| `hazard_interval` | float | 扣血间隔（秒） |
| `hazard_knockback` | float | 水平击退冲量（0 = 不击退） |
| `hazard_knockback_up` | float | 竖直击退冲量（瞬时上抛，独立于水平） |

**机制：**
- 玩家进入危险区立即触发一次扣血，之后按 `hazard_interval` 周期性扣血
- 击退方向为"从危险区中心向外"，水平击退走衰减机制（推开滑动感）
- 竖直击退为**瞬时冲量**（直接作用于 velocity.y，与跳跃同机制），避免落地后残值反复抬升抖动
- `place_building()` 自动为 `hazard_damage > 0` 的建筑附加 Area3D（覆盖占地范围）
- 后续地刺等危险物：新建 .tres 配 `hazard_*` 字段即可复用，无需改代码

**篝火当前配置（campfire.tres）：** `hazard_damage=5.0`、`hazard_interval=0.5`、`hazard_knockback=6.0`、`hazard_knockback_up=2.0`

### 地形系统（v3.4.1+）

**文件：** `scripts/world_3d.gd` — `_create_ground()` / `_get_terrain_height()`

地形由 `models/landscape/地形.glb` GLB 模型驱动，运行时自动适配：

| 步骤 | 说明 |
|------|------|
| 加载模型 | 从 `地形.glb` instantiate，遍历所有 `MeshInstance3D` 计算整体 AABB |
| 自动居中 | 地形最低点沉到 y=0，XZ 居中对齐世界原点 |
| 自动缩放 | XZ 轴等比缩放到 `WORLD_HALF × 2`（100×100），Y 轴保持不变 |
| 碰撞生成 | 从每个 mesh 提取 face 数据，用 `global_transform` 计算世界空间 `ConcavePolygonShape3D`，挂载在独立 `StaticBody3D` 下 |
| 高度查询 | `get_terrain_height_at(x, z)` 射线检测地表，供建造/放置使用 |

**对象适配**：
- 玩家 / 动物 — 从 y=50 高处出生，重力自动着陆
- 掉落物 — 生成时射线检测地表，tween 弹跳到 `地表 + 0.2m`
- 建筑 — 幽灵预览和放置均通过 `get_terrain_height_at()` 贴合地表
- 障碍物 / 资源节点 — 生成时射线检测地表高度

**回退机制**：`地形.glb` 不存在时自动回退到程序化 `PlaneMesh` + 噪声纹理地面。

### 世界范围

| 参数 | 值 | 说明 |
|------|-----|------|
| `WORLD_HALF` | 50.0 | 方形世界回退半径（总大小 100×100） |
| 障碍物 | 100 个 | 随机位置/尺寸（1~4m 宽，1.5~5m 高），固定种子 42 |
| 地图边界 | 地形径向边界 | 运行时从地形网格提取 64 方向边界；障碍物/资源/动物/建筑均在边界内 |

### 岩浆

**文件：** `scripts/world/lava.gd`（`class_name Lava`）

600×600 熔岩表面环绕世界，红灰色 + 红色自发光 + 噪声纹理滚动：

| 属性 | 值 | 说明 |
|------|-----|------|
| `lava_damage_per_sec` | 60.0 | 岩浆伤害/秒 |
| `sink_speed` | 2.0 | 落入后下沉速度 |
| `fall_kill_y` | -20.0 | 掉落保险（过低直接死） |

越界状态（`in_lava`）通知玩家 `set_in_water(true)`，触发水中下沉逻辑。岩浆越界以真实地形碰撞射线为准：玩家正下方射线检测不到地形时判定进入岩浆。

### 自动跨步

**文件：** `scripts/player_3d.gd` — `_step_up()`

贴地行走遇到不超过 `STEP_HEIGHT` 的阻碍时自动抬脚跨过，用 `intersect_shape` 做五步静态几何探测：法线探测→上方净空→抬升后前探→前方地面支撑，全部通过后 `global_position.y += STEP_HEIGHT`。失败后 0.2s CD + 0.3m 位置阻断双重防抖。

| 属性 | 默认值 | 说明 |
|------|--------|------|
| `STEP_HEIGHT` | 0.8 | 跨越高度（m） |
| `STEP_FORWARD` | 0.15 | 最小前探距离 |
| `STEP_FAIL_BLOCK_RADIUS` | 0.3 | 失败位置阻断半径 |

### 地面纹理

**文件：** `scripts/world_3d.gd` — `_make_terrain_texture()`

地面用双层 FastNoiseLite 在代码中生成 512×512 彩色纹理，不再使用纯色 + 灰度噪声：

- **低频噪声**（frequency=0.015, 4 个八度）决定大块生物群落区域
- **高频噪声**（frequency=0.06, 2 个八度）叠加微观像素级亮度波动

地形分区：

| 噪声值 | 地表类型 | 颜色 |
|--------|---------|------|
| `> 0.25` | 草地 | 鲜绿↔黄绿渐变 |
| `-0.15 ~ 0.25` | 泥土过渡带 | 棕色↔草地平滑渐变 |
| `< -0.15` | 石块地 | 灰色混泥色 |

微观细节亮度波动系数 `0.90 + 0.20 × d`，每局游戏随机种子，地形分布不同。

---

## 7. 玩法循环

### 资源节点数据

**文件：** `scripts/world/resource_node.gd`

| 类型 | HP | 掉落 | 数量（世界） |
|------|-----|------|-------------|
| 树 | 40 | 木材×2~4 | 25 |
| 石头 | 60 | 石头×2~4 | 15 |

资源节点重生：白天每 30 秒尝试重生一次（最大 50 个节点），夜晚不重生。重生位置远离玩家 8 米以上。

### 动物数据

**文件：** `scripts/animal_spawner.gd`

| 属性 | 值 | 说明 |
|------|-----|------|
| 初始数量 | 30 | 游戏启动时随机分布 |
| HP | 30 | 无自动回血，受伤后永久保留 |
| 掉落 | 生肉×1~2 | 死亡后掉落 |
| 体型 | 随机 0.4~0.5 | 每只独立缩放 |
| 移动/追击速度 | 白天 walk 1.0~2.0；夜间 run 4.5~5.8 | 每只独立随机 |
| 转向规则 | 移动/跳跃前先原地转向目标方向（模型前方 +Z） | 转好后才移动 |
| 白天行为 | 随机内置动画（一次性动作连续 2~3 次）+ walk 散步 | idle 持续循环 |
| 夜间行为 | 6 米内发现玩家 → run 追击 → 3 米内跳跃攻击 | 10 米外丢失目标 |
| 攻击后停顿 | 1.0 秒 | `post_attack_pause` 可配置 |
| 边界行为 | 统一按真实地形判定 | 白天自行绕开边界；夜间到边界等待/绕行，不原地 run |
| 掉入岩浆 | 可被玩家击退进岩浆 | 以 2m/s 缓慢下沉，挣扎 2 秒（run/gesture-negative）后消失 |
| 种类 | 24 种 | 从河狸、蜜蜂到老虎等 |

砍树/砸石头（近战）→ 掉木材/石头（上抛弹跳→落地滑行→可拾取）→ 走进自动飞向角色 → B 打开建造 →
消耗材料放篝火(发光)/木墙(阻挡)/木地基(平台)。
杀动物 → 掉生肉（右键使用回血 15HP）。走进岩浆 → 持续掉血 → 死亡 → 回存档选择界面。

### 掉落 / 拾取动画

**文件：** `scripts/combat/pickup.gd`（`class_name Pickup`，继承 Node3D）

所有掉落物通过 `Pickup.spawn(parent, item_res, amount, pos)` 静态方法创建，自动执行完整动画流程。

**掉落动画**（spawn → 可拾取）：
- 初始 Y=2.0（上抛），XZ 偏移 ±0.3
- Tween 平行执行（0.6s）：
  - Y: 2.0 → 0.2，`TRANS_BOUNCE` `EASE_OUT`（弹跳落地）
  - XZ: 滑移 ±0.8，`TRANS_QUAD` `EASE_OUT`
- 动画期间 Area3D 碰撞关闭，`_can_pickup = false`
- 动画完成 → `_on_drop_finished()` 更新 `_base_y`，开启拾取
- 掉落动画期间 mesh 持续旋转，不做浮动

**拾取动画**（触发 → 消失）：
- Area3D 半径 1.1m，`body_entered` 检测玩家
- 材料类型：先 `Inventory.add_item()`，放不下则原地保留（不触发飞行）
- 装备/武器：直接触发飞行
- `_fly_to = body`，`_area.monitoring = false`（防重复触发）
- `_process` 飞行分支：`move_toward` 追玩家实时位置，mesh 加速旋转（×3），scale 随距离缩小（`max(dist/1.5, 0.05)`）
- 距离 < 0.3 → `_do_pickup()` 执行最终拾取 → `queue_free()`

**关键变量**（`scripts/combat/pickup.gd`）：
- `_can_pickup: bool` — 掉落动画完成后变为 true
- `_flying_to: Node3D` — 正在飞向的目标（玩家），非 null 时进入飞行分支
- `_fly_speed: float = 6.0` — 飞行速度
- `_area: Area3D` — 拾取碰撞区域，飞行时禁用

### 旋转阻尼

**文件：** `scripts/player_3d.gd`

角色朝向改用 `lerp_angle` 平滑插值，不再瞬时 `look_at`。

- `@export var rotation_lag: float = 0.0` — 转向迟滞，越高越笨重
- `var _target_yaw: float = 0.0` — 目标水平朝向角
- `const ROTATION_DAMPING: float` — 基础旋转速度系数
- 公式：`factor = ROTATION_DAMPING × max(0.05, 1.0 - rotation_lag) × delta`
- 装备的武器可携带 `rotation_lag` 加成，切换时由 `EquipmentManager`（`_set_player_lag`）自动应用到玩家

### 武器属性加减模式

**文件：** `scripts/items/weapon_data.gd` / `scripts/combat/melee_controller.gd`

装备武器不再替换拳头属性，改为**加法叠加**：

```
最终属性 = 拳头基础值 + 武器加成值
```

`melee_controller.gd` 的 `_do_attack()` 使用 `fist_XXX + weapon.XXX` 计算。武器 `.tres` 文件中定义的属性均为**加成值**（可为正负），不设则默认为 0（无加成）。

可加成属性：`damage`、`attack_range`、`attack_arc`、`cooldown`、`knockback`、`rotation_lag`、`has_projectile_vfx`

**示例**——木剑（`data/items/weapons/sword_wood.tres`）：
- 加成值填在 .tres 中，拳头基础值在 `melee_controller.gd` 顶部定义
- 武器伤害最终 = 拳头伤害 + 武器加成

### 攻击判定范围

**类型：** 圆柱（自 v3.3.4 起）
**文件：** `scripts/combat/melee_controller.gd` — `_apply_hits()`

攻击范围由两个参数定义，单位均为**米**：
- `fist_range` — 前方攻击距离（拳头默认 1m）
- `fist_arc` — 圆柱半径（拳头默认 0.3m，原名 arc 沿用）
- 武器通过 `attack_range` / `attack_arc` 加成叠加

判定方式：
1. 将目标位置转换到玩家局部空间
2. 检查 Z 是否落在 `[-rng, 0]` 内（前方）
3. 检查横向距离 `sqrt(x² + y²)` ≤ 半径（含 0.4m 宽容度）
4. **Y 轴高度参与计算**，高度差过大的目标不会被命中

**碰撞体积判定**（而非中心点）：
- 自动查找目标的 CollisionShape3D
- 支持 SphereShape3D、CapsuleShape3D、CylinderShape3D、BoxShape3D
- 提取碰撞体半径加到宽容度中，目标**边缘进入范围即可命中**
- 无碰撞体的目标按中心点判定

`melee_controller.gd` 顶部 `@export` 变量为拳头基础值，`data/items/weapons/*.tres` 中的值为武器加成值，最终范围 = 拳头基础 + 武器加成。

### 武器攻击视觉特效

**文件：** `scripts/combat/melee_controller.gd` / `scripts/vfx/thrust_beam_vfx.gd` / `shaders/thrust_beam.gdshader`

装备武器时可通过 `has_projectile_vfx = true` 开启攻击特效。当前支持**突刺光束**（ThrustBeam）：

- 模型：`models/vfx/ThrustBeam.glb`（锥形能量柱，1m 长，+Y 方向建模）
- 着色器：`shaders/thrust_beam.gdshader` — 从柄向尖端生长 + 噪声能量流动 + Fresnel 边缘淡出
- 控制脚本：`scripts/vfx/thrust_beam_vfx.gd`

**时序（固定，不可调）：**
| 时间 | 事件 |
|------|------|
| 0.0s | 点击攻击，VFX 计时开始 |
| 0.1s | 光束从柄向尖端展开（progress 0→1） |
| 0.14s | 侧向溅射粒子 + 尖端爆开粒子 |
| 0.2s | 全部特效结束，自动清理 |

粒子效果：
- `SideSplash` — 沿光束柱身的盒形区域持续发射，粒子沿径向溅射
- `ImpactBurst` — 尖端处球形区域一次爆开，白→蓝色消散

攻击伤害（近战扇形判定）与 VFX 互相独立，伤害命中时机由 `hit_delay` 控制。

### 受击反馈（health.gd 自动系统）

**文件：** `scripts/combat/health.gd`（`class_name Health`，继承 Node）

受击反馈完全由 `Health.take_damage()` 自动触发，不依赖外部信号连接。所有挂载 Health 的实体（玩家、动物、资源节点）自动获得以下两种反馈：

#### 1. 模型红色闪烁

在 `take_damage()` 中调用 `_tint_parent_red()`：
- 遍历 `get_parent().find_children("*", "MeshInstance3D", true, false)`
- 对每张材质 `duplicate()`，设 `albedo_color = RED`，通过 `set_surface_override_material()` 应用
- 创建 Tween，0.3s 内渐回原色
- 资源节点同样生效（代码创建的 StandardMaterial3D 材质）

#### 2. 溅射粒子系统

在 `take_damage()` 中调用 `_spawn_hit_particles(from_position)`。

**粒子参数：**
```
draw_pass_1: SphereMesh(radius=0.15, height=0.3)
材质: StandardMaterial3D
  - transparency = TRANSPARENCY_ALPHA
  - shading_mode = SHADING_MODE_UNSHADED
  - vertex_color_use_as_albedo = true  ← 关键：让粒子颜色生效
  - blend_mode = BLEND_MODE_ADD        ← 加色混合，重叠变亮产生发光
  - albedo_color = WHITE
  - emission = WHITE, energy = 12.0
ParticleProcessMaterial:
  - amount = 20, lifetime = 0.15
  - spread = 180°, gravity = (0, -6, 0)
  - initial_velocity = 2~6
  - scale = 0.2~0.4
  - alpha_curve: 0.0→0.5, 0.2→0.5, 1.0→0.0  (初始低透0.5，前0.2生命周期保持0.5透明，到死亡时逐渐透明降到0)
```

**粒子颜色** — 通过 `Health.set_particle_color(Color)` 在每个实体的创建位置预设：
- 树（`resource_node.gd:108`）→ `Color(0.40, 0.26, 0.13)` 树干棕
- 石头（`resource_node.gd:108`）→ `Color(0.45, 0.45, 0.48)` 灰色
- 动物（`animal_spawner.gd:128` / `world_3d.gd:449`）→ `Color(0.75, 0.3, 0.3)` 生肉红
- 玩家 → 未设，默认 `Color.WHITE`

**表面偏移** — 粒子从受击方向的表面发出：
1. 遍历父节点下所有 MeshInstance3D 的 AABB，取 4 个底角
2. 转换到父节点局部空间，计算最大 XZ 距离作为半径
3. `radius = max(radius, 0.3)` 保底
4. `radius *= 0.6 × particle_offset_scale`（两层系数：全局 0.6 + 实体自身系数）
5. `ps.position = from_attacker_direction.normalized() × radius`

**实体偏移系数**（`particle_offset_scale`，默认 1.0）：
- 通过 `Health.set_particle_offset_scale(float)` 设置
- 树设为 `0.3`（`resource_node.gd`，树冠大但希望粒子集中在树干附近）
- 石头/动物/玩家均为默认 `1.0`

#### ⚠️ 粒子颜色踩坑记录（供后续 agent 参考）

粒子颜色和发光在实现过程中踩了几个坑，记录如下：

**坑 1：`@export var` 通过 `set()` 赋值可能不生效**
- 最初用 `@export var particle_color: Color = Color.WHITE` + `health.set("particle_color", Color(...))`
- 在 `add_child` 之前调用 `set()`，属性有时无法正确写入
- 改为普通 `var particle_color` + `func set_particle_color(c: Color)` 方法调用，问题解决
- `max_hp` 也用 `set()` 但能正常工作，因为 `_ready()` 中会读取它

**坑 2：`draw_pass` 材质默认忽略粒子颜色（根因）**
- 使用 `draw_pass_1 = SphereMesh` 时，mesh 的 `StandardMaterial3D` 默认用固定 `albedo_color`
- `ParticleProcessMaterial.color` 传入的粒子颜色不会自动应用到 mesh 上
- 必须在 mesh 材质上设置 `vertex_color_use_as_albedo = true`，粒子颜色才生效
- 在此之前所有粒子始终显示白色（材质固定白），无论 `particle_color` 设成什么

**坑 3：发光需要 `BLEND_MODE_ADD` 加色混合**
- 光靠 `emission_enabled + emission_energy_multiplier` 不足以让粒子有可见发光
- 必须同时设置 `blend_mode = BLEND_MODE_ADD`，重叠粒子会变亮，产生发光效果
- 加色混合模式下透明度由 alpha 值控制 ADD 强度

**坑 4：`GPUParticles3D` 无 `draw_pass` 可能不渲染**
- 不设 `draw_pass` 时使用默认点精灵渲染，但在某些 Godot 版本/配置下可能完全不可见
- 设置 `draw_pass_1` 并使用显式 mesh 是最稳妥的方式

**坑 5：透明度需要材质配合**
- `alpha_curve` 需要 `CurveTexture`（不是直接 `Curve`）
- 材质必须设置 `transparency = TRANSPARENCY_ALPHA`，否则 alpha 被忽略
- 透明 + 加色混合可以同时存在，alpha 控制加色强度

**坑 6：`visibility_aabb` 必须设置**
- GPUParticles3D 默认 `visibility_aabb` 为空，粒子被视锥裁剪，完全不可见
- 必须手动设一个足够大的 AABB：`AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))`

**相关文件：**
- `scripts/combat/health.gd` — 粒子生成和颜色管理
- `scripts/world/resource_node.gd:108` — 树/石头颜色预设
- `scripts/animal_spawner.gd:128` — 动物受击粒子颜色预设
- `scripts/world_3d.gd:449` — 动物重生颜色预设

### 玩家 HUD

**文件：** `scripts/world_3d.gd`

左上角半透明面板 + 绿色填充条 + 数字（"当前HP / 最大HP"）：

- 填充条宽度 = 214px × HP 比例
- 颜色渐变：`HP > 50%` 绿→黄，`HP ≤ 50%` 黄→红
- 位置：(15, 280)，尺寸 220×26

#### 受伤红闪

受击时全屏红色闪烁 0.3s 淡出：
- `Color(1, 0, 0, 0.3)` → tween 到 alpha=0
- 层级 380（最高 UI 层），`mouse_filter = IGNORE`

#### 受击击退

玩家受击时，由 `world_3d._knockback_player(from)` 触发：
- 方向：远离伤害来源（水平）
- 冲量：8.0（硬编码）
- 衰减：`_knockback.lerp(Vector3.ZERO, delta × 4.0)`，约 0.5 秒归零
- 纯水平推开，不干扰跳跃判定

### 动物推挤

动物不检测玩家碰撞（玩家 `collision_mask = 1`，动物在层 2），取而代之的是代码推挤：

- 检测距离 0.6m （PUSH_DISTANCE）
- 推挤冲量：`push_impulse_min/max`（1.5~4.5），受玩家移速加成（×10×(1.0 - dist / PUSH_DISTANCE)）
- 推挤冷却：0.25s

---

## 8. 昼夜与夜间狂暴

**文件：** `scripts/day_night_cycle.gd`（`class_name DayNightCycle`）

### 时间模型（v3.4.2+ 重构）

时间以**归一化进度** `day_progress`（0.0~1.0）记录：`0.0 = 0:00`、`0.25 = 6:00`、`0.5 = 12:00`。24h 制时钟由进度推导（`day_progress × 24`），**与总时长完全解耦**。

**★ 一天总时长单点配置**（`day_night_cycle.gd` 顶部）：

```gdscript
@export var seconds_per_day: float = 480.0  # 480 = 8分钟一天
```

调整该值即可改变白天/夜晚总时长，时钟显示、存档、动物昼夜行为自动适配，不会出错。默认 **8 分钟一天**。

### 存档兼容

- 新存档：保存 `day_progress`（归一化进度，与总时长无关）
- 旧存档自动迁移：检测到旧字段 `day_time`（绝对游戏秒）时换算为进度后恢复

### 夜间 (19:00 ~ 6:00)

| 机制 | 白天 | 夜间 |
|------|------|------|
| 动物行为 | 随机内置动画（idle/dance/eat/gesture/static）+ walk 散步 | 未发现玩家时同白天；发现后狂暴 |
| 动物追击 | 无 | 6 米内发现，run 动画追击，10 米外丢失 |
| 动物近身攻击 | 无 | 3 米内恢复原跳跃攻击（冲量 6.0/5.0），落点 2 米内扣 5 HP |
| 追击到边界 | 无 | 停止 run，原地等待或沿边界绕行，目标回到安全位置后恢复追击 |
| 攻击后停顿 | 无 | 原地停留 1 秒，再继续追击 |
| 资源重生 | 每 30 秒 | 不重生 |
| 动物重生 | 每 45 秒 | 不重生 |

### 动物重生机制

**文件：** `scripts/world_3d.gd` — `_try_regen_animal()`

重生定时器每 45 秒触发一次，仅在白天（6:00~19:00）生效：

1. 统计世界中的存活动物（`RigidBody3D` + `"damageable"` 组）
2. 若 ≥ 30 只，跳过重生
3. 否则随机选一种动物模型，在世界范围内寻找空地
4. 生成位置远离玩家 **10 米以上**，避开障碍物
5. 新动物随机属性：体型 0.4~0.5、白天 walk 速度 1.0~2.0、夜间 run 速度 4.5~5.8

**注意：** 动物**没有血量恢复**，受伤后 HP 永久保留直到死亡。

### 受伤反馈

- 屏幕红色闪烁（0.3 秒淡出，仅玩家）
- **模型材质变红 0.3s**（health.gd 自动处理，玩家/动物/资源节点全覆盖）
- **溅射粒子**（health.gd 自动处理，圆形发光小球 + 透明度衰减）
- 击退冲量：apply_knockback + lerp 衰减（~0.5秒），纯水平推开不干扰跳跃

### 装备与物品使用

**背包右键菜单**（装备 / 卸下 / 使用）：
- 功能装备（手电筒、火把）和武器（木剑）：右键 → **装备** / **卸下**，"使用"灰色禁用
- 消耗品（生肉）：右键 → **装备**（放入快捷栏） / **卸下**（从快捷栏移除） / **使用**（消耗一个回血 15HP）

**装备栏三区操作**：
- **F** 循环切换功能装备 → 激活光源效果，底部栏高亮当前装备
- **Q** 循环切换武器 → 应用武器属性（伤害/范围/击退/迟滞），底部栏高亮当前武器
- **1/2/3** 使用消耗品 → 消耗背包中对应物品，触发 8s 冷却，冷却以灰色覆盖条从底部向上缩小动画显示
- 装备的物品在背包中**金色边框高亮**，卸下后取消高亮

**装备新物品**：`data/items/equipment/` 下新建 .tres（Equipment 类），ItemDB 自动收录。
`ItemData.heal_amount > 0` 即可食用的消耗品，新增物品设此属性即可。

---

## 9. 存档系统

### 存档选择界面

启动后进入 SaveSelectScreen，左侧 5 个存档槽位，右侧 3D 角色预览（自动旋转）：

- **空槽位** →「新建」→ 角色选择 → 新游戏 → 自动存档
- **已有存档** →「进入」→ 直接加载世界状态
- **删除按钮** → 确认弹窗 → 删除存档文件
- **动画预览** → 底部 4 列动画按钮，点击循环播放，再次点击停止
- **退出游戏** → 底部退出按钮
- **自定义路径** →「设置路径」打开文件夹选择器 →「恢复默认」重置，均有确认弹窗

### 存档内容

存档为 JSON 文件，默认位于 `user://saves/slot_0.json` ~ `slot_4.json`，路径可自定义：

| 类别 | 存储内容 |
|------|---------|
| 玩家 | 位置 (x,y,z)、血量、背包全部格子、装备三区数据（功能装备ID列表+当前索引 / 武器ID列表+当前索引 / 消耗品栏位ID数组+冷却状态）、角色模型/皮肤 |
| 世界 | 昼夜时间、已放置建筑、资源节点位置(树/石头)、存活动物数量 |
| 元数据 | 版本号、时间戳、累计游玩时长 |

### 存档触发

| 方式 | 触发 | 反馈 |
|------|------|------|
| 手动 | Esc → 暂停菜单 →「保存游戏」 | 菜单内 "游戏已保存 ✓"（2秒） |
| 自动 | 每 60 秒 | 屏幕中央 "游戏已保存"（淡出） |
| 退出 | 关闭游戏窗口 | 静默保存 |
| 初始 | 新游戏开始后 | 立即创建存档 |

### 自定义存档路径

路径配置保存在 `user://save_config.json`，支持任意目录：

```
SaveManager.set_save_dir("D:/MySaves")     # 设置自定义路径
SaveManager.reset_save_dir()               # 恢复默认 user://saves
SaveManager.get_display_path()             # 获取实际绝对路径
```

### 数据流

```
SaveManager (RefCounted 静态工具类)
  ├── list_saves()      → 获取 5 个槽位信息（轻量，不加载完整数据）
  ├── load_save(slot)   → 读取完整 JSON
  ├── save_game(slot, data) → 写入 JSON
  ├── delete_save(slot) → 删除文件
  ├── set_save_dir(path) → 自定义存档目录
  └── reset_save_dir()  → 恢复默认路径

world_3d._collect_save_data()  → 收集玩家+世界状态
world_3d._restore_from_save()  → 恢复位置/血量/背包/建筑/昼夜
```

---

## 10. 碰撞层

| 层 | 对象 |
|----|------|
| 1 | 地面、障碍物、资源节点、建筑、玩家 |
| 2 | 动物 (RigidBody3D, continuous_cd=true) |

玩家与动物间无物理碰撞（代码推挤）；近战命中靠 `"damageable"` 组 + 距离/角度判定。

---

## 11. 场景可视化（v3.5.0+）

v3.5.0 将原先纯代码生成的 3D 内容场景化，**大部分内容现在可在 Godot 编辑器中直接编辑**：

### 可在编辑器中可视化编辑

| 内容 | 位置 | 说明 |
|------|------|------|
| 地形 / 光照 / 环境 | `scenes/main.tscn` | Terrain（地形模型）、SunLight、MoonLight、WorldEnv 均为场景节点，可直接调整位置/旋转/参数 |
| 玩家结构 | `scenes/player.tscn` | 模型占位、碰撞体、手电筒/火把灯光、Inventory/Health/MeleeController/EquipmentManager 均为场景子节点 |
| 树 / 石头 | `scenes/prefabs/tree.tscn` / `rock.tscn` | mesh、材质、碰撞体可编辑；位置仍由代码随机生成 |
| 掉落物 | `scenes/prefabs/pickup.tscn` | 模型、标签、拾取区可编辑；颜色/标签文本运行时按物品覆盖 |
| 障碍物 | `scenes/prefabs/obstacle.tscn` | 单位尺寸（1×1×1），运行时按随机尺寸缩放；材质运行时覆盖 |
| 建筑外观 | `scenes/prefabs/building_*.tscn` | 篝火/木地基/木墙；`BuildingData.scene_path` 指向预制体，可加自定义 mesh/粒子 |
| 物品/建筑数值 | `data/items/*.tres`、`data/buildings/*.tres` | 检查器直接编辑（伤害、回血、成本、尺寸等） |

**碰撞体优先级（玩家/资源/障碍物）：** 在 `.tscn` 中手动调整的 `CollisionShape3D`（形状/位置/大小）即最终碰撞体积，**完全可视化编辑、所见即所得**；仅当场景中没有对应碰撞节点时才回退到基于 mesh AABB 的自动计算。

### 装备光源职责划分

灯光参数按来源分工（手电筒/火把/篝火）：

| 参数 | 配置位置 | 说明 |
|------|---------|------|
| 位置 / 旋转 | `.tscn`（player.tscn / building_*.tscn） | 编辑器可视化摆放，装备切换不覆盖 |
| 光锥角度 `spot_angle` | `.tscn`（SpotLight 节点） | 手电筒光锥范围 |
| 强度 `light_energy` | `.tres`（equipment/*.tres、buildings/*.tres） | 手电 5 / 火把 5 / 篝火 3.5 |
| 射程 / 衰减 | `.tres` | `spot_range`/`omni_range`、`spot_attenuation`/`omni_attenuation` |
| 颜色 / 阴影 | `.tres` | `light_color`、`shadow_enabled`（动态光关阴影避免玩家产生影子） |

### 保留代码生成的部分

- **障碍物/树/石头/动物的位置** — 代码随机生成（保持每局布局随机性），外观来自预制体
- **动物** — 模型多样（24 种），仍为代码生成（可仿照资源节点预制体化）
- **UI（背包/装备栏/建造菜单）** — 全代码生成

### 预制体架构

```
场景加载时:
  main.tscn 提供 Terrain + 光照/环境
  world_3d._create_ground()  → _fit_terrain() 居中缩放 + 运行时构建地形碰撞
  world_3d._create_obstacles() → instantiate obstacle.tscn + 随机尺寸/材质
  resource_node.spawn()       → instantiate tree.tscn / rock.tscn（位置随机）
  pickup.spawn()              → instantiate pickup.tscn
  place_building()            → 优先 instantiate building_*.tscn（scene_path），空则回退 BoxMesh
```

**回退机制**：所有预制体加载失败时自动回退到程序化构建（BoxMesh 等），保证可运行。

---

## 12. 注意事项

- **导出的 .remap 后缀**：导出包里 DirAccess 列出的文件是 `xxx.tres.remap`，扫描目录时必须 `trim_suffix(".remap")` 再判断和加载（ItemDB / BuildController 已处理）
- **Object.get 冲突**：自定义静态方法不能叫 `get`（与原生冲突），ItemDB 用 `get_item`
- **AABB.position**：Godot 4 中是最小角，中心 = `position + size*0.5`
- **UI 缩放**：1920x1080 参考，scale 0.6~1.6
- **GLB 动画**：attack-melee-* 用于挥击，die 用于死亡，均设 LOOP_NONE
- **幽灵合法性**：占地(占用AABB) + 世界边界 + 材料是否足够，三者同时决定绿/红
- **存档位置**：默认 `user://saves/`（Windows: `%APPDATA%/Godot/app_userdata/TopDownGame3D/saves/`），可在游戏内自定义
- **路径配置**：`user://save_config.json`，SaveManager 启动时自动加载，无需手动编辑
- **SaveManager 为静态 RefCounted**：无需实例化，直接 `SaveManager.save_game(slot, data)` 调用
- **资源持久化**：树和石头位置存入存档，重新加载后不会随机重置
- **动物行为**：动画名由 GLB 内置 `AnimationPlayer` 动态映射（所有动物共用同一套动画）；动物模型前方为 **+Z**，转向公式为 `atan2(dir.x, dir.z)`；所有边界/岩浆判定统一使用地形专用射线层（第 4 层）；夜间通过 `"day_night_system"` 组查找昼夜系统，无直接引用依赖
