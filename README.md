# TopDownGame3D v3.2

> Godot 4.7.1 · 俯视角 3D · 全 GDScript · 2026-07-22

---

## 1. 项目路径

```
F:/godot_stuff/projects/topdown_game_3d-v3/
```

GitHub (公开)：`https://github.com/Qq-zhang02/topdown_game_3d`

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
│   │   ├── health.gd          # 通用血量组件（玩家/动物/资源节点共用）
│   │   ├── melee_controller.gd# 近战：左键扇形判定，伤害取自当前 WeaponData
│   │   └── pickup.gd          # 掉落物：走近自动拾取（材料→背包，装备→装备管理器）
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
│   ├── player_3d.gd           # 玩家：移动/朝向/装备/血量/背包/近战/动画
│   ├── equipment.gd           # 光源装备（继承 ItemData：手电筒/火把）
│   ├── equipment_manager.gd   # 装备管理器（F 切换，武器也走这里）
│   ├── equipment_hud.gd       # 底部装备栏
│   ├── camera_follow_3d.gd / minimap_3d.gd / day_night_cycle.gd
│   ├── animal_spawner.gd      # 动物生成（+血量/掉落生肉）
│   ├── animal_behavior.gd     # 动物行为
│   ├── save_manager.gd           # ★ 存档管理器：5槽位，JSON读写 user://saves/
│   ├── save_select_screen.gd     # ★ 存档选择界面：新建/进入/删除
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
      ├── 菜单 / 昼夜 / 时间显示
      └── 初始存档 + 启动自动存档定时器
```

---

## 4. 操作

| 按键 | 功能 |
|------|------|
| WASD / 鼠标 / Space | 移动 / 朝向 / 跳跃 |
| **鼠标左键** | 近战攻击（手持武器用武器参数，否则拳头） |
| F | 切换装备（手电筒→火把→木剑→关） |
| **Tab** | 背包（拖拽整理） |
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

**信号解耦：** `health.died` / `inventory.changed` / `build_menu.recipe_selected`，系统间不直接引用。

**占地管理：** 世界维护 `_occupied: Array[AABB]`（障碍物/资源/建筑），
`is_area_free(center, half)` 统一做建造合法性校验；资源被采完自动释放占地。

---

## 6. 玩法循环

砍树/砸石头（近战）→ 掉木材/石头 → 自动拾取进背包 → B 打开建造 →
消耗材料放篝火(发光)/木墙(阻挡)/木地基(平台)。
杀动物 → 掉生肉。走进海里 → 持续掉血 → 死亡 → 回存档选择界面。

---

## 7. 存档系统 ★ v3.2 新增

### 存档内容

存档为 JSON 文件，位于 `user://saves/slot_0.json` ~ `slot_4.json`：

| 类别 | 存储内容 |
|------|---------|
| 玩家 | 位置 (x,y,z)、血量、背包全部格子、当前装备索引、角色模型/皮肤 |
| 世界 | 昼夜时间 (game_time)、已放置建筑（资源路径+位置+旋转） |
| 元数据 | 版本号、时间戳、累计游玩时长 |

### 存档触发

| 方式 | 触发 | 反馈 |
|------|------|------|
| 手动 | Esc → 暂停菜单 →「保存游戏」 | 菜单内 "游戏已保存 ✓"（2秒） |
| 自动 | 每 60 秒 | 屏幕中央 "游戏已保存"（淡出） |
| 退出 | 关闭游戏窗口 | 静默保存 |
| 初始 | 新游戏开始后 | 立即创建存档 |

### 存档操作

- **最多 5 个存档位**，超出需删除旧存档
- 空槽位「新建」→ 角色选择 → 新游戏
- 已有存档「进入」→ 直接加载世界状态
- 删除需要确认对话框

### 数据流

```
SaveManager (RefCounted 静态工具类)
  ├── list_saves()      → 获取 5 个槽位信息（轻量，不加载完整数据）
  ├── load_save(slot)   → 读取完整 JSON
  ├── save_game(slot, data) → 写入 JSON
  ├── delete_save(slot) → 删除文件
  └── has_save(slot)    → 检查是否存在

world_3d._collect_save_data()  → 收集玩家+世界状态
world_3d._restore_from_save()  → 恢复位置/血量/背包/建筑/昼夜
```

---

## 8. 碰撞层

| 层 | 对象 |
|----|------|
| 1 | 地面、障碍物、资源节点、建筑、玩家 |
| 2 | 动物 (RigidBody3D, continuous_cd=true) |

玩家与动物间无物理碰撞（代码推挤）；近战命中靠 `"damageable"` 组 + 距离/角度判定。

---

## 9. 注意事项

- **导出的 .remap 后缀**：导出包里 DirAccess 列出的文件是 `xxx.tres.remap`，扫描目录时必须 `trim_suffix(".remap")` 再判断和加载（ItemDB / BuildController 已处理）
- **Object.get 冲突**：自定义静态方法不能叫 `get`（与原生冲突），ItemDB 用 `get_item`
- **AABB.position**：Godot 4 中是最小角，中心 = `position + size*0.5`
- **UI 缩放**：1920x1080 参考，scale 0.6~1.6
- **GLB 动画**：attack-melee-* 用于挥击，die 用于死亡，均设 LOOP_NONE
- **幽灵合法性**：占地(占用AABB) + 世界边界 + 材料是否足够，三者同时决定绿/红
- **存档位置**：`user://saves/`（Windows: `%APPDATA%/Godot/app_userdata/TopDownGame3D/saves/`），JSON 格式可直接查看/编辑
- **SaveManager 为静态 RefCounted**：无需实例化，直接 `SaveManager.save_game(slot, data)` 调用
