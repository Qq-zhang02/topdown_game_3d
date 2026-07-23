# TopDownGame3D v3.3.4

> Godot 4.7.1 · 俯视角 3D · 全 GDScript · 2026-07-24

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
│   ├── main.tscn              # 入口 (Node3D → world_3d.gd)
│   └── player.tscn            # 玩家 (CharacterBody3D → player_3d.gd)
├── data/                      # ★ 数据驱动内容：新增物品/建筑 = 加 .tres，零代码
│   ├── items/                 # 物品（ItemDB 自动扫描，按 id 取用）
│   │   ├── wood.tres / stone.tres / meat.tres
│   │   └── weapons/sword_wood.tres
│   └── buildings/             # 建筑配方（BuildController 自动扫描）
│       ├── campfire.tres / wooden_wall.tres / foundation.tres
├── scripts/
│   ├── core/
│   │   ├── item_data.gd       # 物品基类 Resource（ItemType: MATERIAL/EQUIPMENT/WEAPON）
│   │   ├── item_stack.gd      # 背包格子 {item, count}
│   │   └── item_db.gd         # 物品数据库：扫描 data/items/，ItemDB.get_item(id)
│   ├── inventory/
│   │   ├── inventory.gd       # 背包数据层：32格，增删/堆叠/消耗，changed 信号
│   │   ├── inventory_ui.gd    # 背包界面：8x4，Tab 开关，拖拽整理
│   │   └── inventory_slot.gd  # 背包格子（拖拽逻辑）
│   ├── combat/
│   │   ├── health.gd          # 通用血量组件（受击红闪+溅射粒子，自动覆盖所有挂载者）
│   │   ├── melee_controller.gd# 近战：左键扇形判定，伤害取自当前 WeaponData
│   │   └── pickup.gd          # 掉落物：上抛弹跳→滑行→可拾取，触发后飞向角色消失
│   ├── building/
│   │   ├── building_data.gd   # 建筑定义：尺寸/颜色/材料消耗/发光
│   │   ├── build_controller.gd# 建造模式：幽灵预览(绿/红)+网格吸附+R旋转
│   │   └── build_menu_ui.gd   # 建造菜单：配方列表，材料不足置灰
│   ├── world/
│   │   ├── ocean.gd           # 海洋：滚动水面，越界落水持续掉血
│   │   ├── resource_node.gd   # 可采集资源：树(掉木材)/石头(掉石头)
│   │   └── death_screen.gd    # 死亡界面 → 回开始界面
│   ├── items/
│   │   └── weapon_data.gd     # 近战武器数据（继承 ItemData）
│   ├── world_3d.gd            # 世界总管（占地登记/建造放置/各系统组装）
│   ├── player_3d.gd           # 玩家：移动/朝向(反应速度阻尼)/装备/血量/背包/近战/动画
│   ├── equipment.gd           # 光源装备（继承 ItemData：手电筒/火把）
│   ├── equipment_manager.gd   # 装备管理器（F 切换，武器也走这里）
│   ├── equipment_hud.gd       # 底部装备栏
│   ├── camera_follow_3d.gd / minimap_3d.gd / day_night_cycle.gd
│   ├── animal_spawner.gd      # 动物生成（+血量/掉落生肉）
│   ├── animal_behavior.gd     # 动物行为
│   ├── save_manager.gd           # ★ 存档管理器：5槽位，JSON读写，可自定义路径
│   ├── save_select_screen.gd     # ★ 存档选择界面：3D预览+动画预览+新建/进入/删除
│   ├── start_screen.gd / menu_manager.gd / keybind_menu.gd / time_display.gd
└── models/                    # 角色 + 24种动物 GLB
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
      ├── _create_ocean()           → 海洋（边界，落水掉血）
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
| F | 切换装备（手电筒→火把→木剑→关） |
| **Tab** | 背包（拖拽整理，右键使用可食用物品） |
| **B** | 建造菜单 → 选配方 → 幽灵预览 → 左键放置 |
| **R** | 建造时旋转 90° |
| 右键(按住) | 瞄准；建造中点右键取消 |
| Esc | 暂停菜单（继续/保存/重新开始/返回/按键/退出） |

---

## 5. 核心设计（扩展性）

**一切皆数据，新增内容不改代码：**

- **新物品/材料** → `data/items/` 加 .tres（ItemData），ItemDB 自动收录
- **新武器** → `data/items/weapons/` 加 .tres（WeaponData：伤害/范围/角度/冷却/击退）
- **新建筑** → `data/buildings/` 加 .tres（BuildingData：尺寸/颜色/成本/发光），建造菜单自动出现
- **新的可攻击对象** → 挂 `health.gd`（命名 "Health"）+ 加入 `"damageable"` 组，近战即可命中
- **新光源装备** → 代码里 new Equipment（参考 player_3d.gd `_make_torch`）
- **新掉落物** → `Pickup.spawn(parent, item_res, amount, pos)` 自动处理掉落动画 + 拾取飞行，按 `item_type` 分流到背包或装备管理器
- **受击反馈** → 任何挂载 `health.gd` 的实体自动获得：模型闪红 0.3s + 彩色溅射粒子。粒子颜色通过 `set_particle_color()` 设置，默认白色

**信号解耦：** `health.died` / `inventory.changed` / `build_menu.recipe_selected`，系统间不直接引用。

**占地管理：** 世界维护 `_occupied: Array[AABB]`（障碍物/资源/建筑），
`is_area_free(center, half)` 统一做建造合法性校验；资源被采完自动释放占地。

---

## 6. 玩法循环

砍树/砸石头（近战）→ 掉木材/石头（上抛弹跳→落地滑行→可拾取）→ 走进自动飞向角色 → B 打开建造 →
消耗材料放篝火(发光)/木墙(阻挡)/木地基(平台)。
杀动物 → 掉生肉（右键使用回血 15HP）。走进海里 → 持续掉血 → 死亡 → 回存档选择界面。

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

**类型：** 矩形（自 v3.3.4 起）
**文件：** `scripts/combat/melee_controller.gd` — `_apply_hits()`

攻击范围由两个参数定义，单位均为**米**：
- `fist_range` — 前方攻击距离（拳头默认 1m）
- `fist_arc` — 左右半宽（拳头默认 0.3m，总宽 0.6m）
- 武器通过 `attack_range` / `attack_arc` 加成叠加

判定方式：将目标位置转换到玩家局部空间，检查是否落在 `[-rng, 0]` × `[-half_w, half_w]` 矩形内（含 0.4m 宽容度）。

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
- `scripts/animal_spawner.gd:128` — 动物颜色预设
- `scripts/world_3d.gd:449` — 动物重生颜色预设

---

## 7. 昼夜与夜间狂暴 ★ v3.3 新增

昼夜系统 60 倍速（现实 1 分钟 = 游戏 1 小时），24 分钟一天。

### 夜间 (19:00 ~ 6:00)

| 机制 | 白天 | 夜间 |
|------|------|------|
| 动物弹跳间隔 | 1~4 秒 | 0.5~2 秒（减半） |
| 动物跳向玩家 | 不 | 8 米内主动跳向玩家 |
| 动物落地伤害 | 无 | 落点 2 米内 → 扣 8 HP |
| 动物跳跃冲量 | 2.0/3.5 | 6.0/5.0 |
| 资源重生 | 每 30 秒 | 不重生 |
| 动物重生 | 每 45 秒 | 不重生 |

### 受伤反馈

- 屏幕红色闪烁（0.3 秒淡出，仅玩家）
- **模型材质变红 0.3s**（health.gd 自动处理，玩家/动物/资源节点全覆盖）
- **溅射粒子**（health.gd 自动处理，圆形发光小球 + 透明度衰减）
- 击退冲量：apply_knockback + lerp 衰减（~0.5秒），纯水平推开不干扰跳跃

### 物品使用

- 背包右键使用可食用物品（生肉 ♥15 回血）
- `ItemData.heal_amount > 0` 即可食用，新增物品设此属性即可

---

## 8. 存档系统

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
| 玩家 | 位置 (x,y,z)、血量、背包全部格子、当前装备索引、角色模型/皮肤 |
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

## 9. 碰撞层

| 层 | 对象 |
|----|------|
| 1 | 地面、障碍物、资源节点、建筑、玩家 |
| 2 | 动物 (RigidBody3D, continuous_cd=true) |

玩家与动物间无物理碰撞（代码推挤）；近战命中靠 `"damageable"` 组 + 距离/角度判定。

---

## 10. 注意事项

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
- **动物行为**：夜间通过 `"day_night_system"` 组查找昼夜系统，无直接引用依赖
