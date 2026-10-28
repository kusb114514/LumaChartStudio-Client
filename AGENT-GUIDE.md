# LumaChart Studio —— 给 AI agent 的使用说明

> 这个文件夹是 **LumaChart Studio**（Malody / osu!mania 谱面编辑器）的一个**非官方 Windows 构建**。
> 本文件写给**要代替人来操作这个客户端的 AI agent**：你能用命令行工具 `lumatool` 读写谱面，
> 也能直接读编辑器的本地元数据文件。
>
> ⚠️ **先读完第 2 节「beat 编号」再动手。** 那是这个项目最容易搞错、也最容易把谱面改坏的一件事。

---

## 1. 你能用到的文件

| 东西 | 位置 | 说明 |
|---|---|---|
| 编辑器本体 | `LumaChart.Avalonia.exe` | 图形界面，人在用；**不要**在它开着同一张谱时去写文件 |
| 命令行工具 | `lumatool\lumatool.exe` | **agent 的主要入口**：`dump` / `write` 谱面。自包含，不需要额外装 .NET |
| 谱面库 | `LumaChart Workspace\<曲目名>\<数字id>.mc` | 用户的工作区。**靠扫描目录发现谱面**，没有清单文件 |
| 编辑器元数据 | `%LocalAppData%\LumaChart Studio\Avalonia\chart-group-catalog.json` | 分组名 / 颜色 / 父子层级 / 分组预设 / 批注 / 批注预设 |
| 其余设置 | 同上目录 `shortcuts.json`、`workspace.json` 等 | 一般不用碰 |

`lumatool` 的两条输出纪律：**stdout 只出 JSON**（可以直接喂给解析器），**给人看的信息全部走 stderr**。

---

## 2. ⚠️⚠️ beat 编号：存储值比界面显示**小 1**

- **用户在界面上看到的** = 时间轴左侧刻度栏印的 = **Malody 自己的编辑器显示的** → 从 **1** 开始数。
- **`.mc` 文件里、`lumatool` 的 JSON 里、`chart-group-catalog.json` 里** → 从 **0** 开始数。
- 换算只有一句：**`JSON 里的 bar = 用户说的 beat − 1`**。

拿一张**假设的** 4/4 谱（8 分音符对齐）当例子 —— 用户口中的「拍」= 小节编号：

| 用户会这么说 | JSON / `.mc` 里实际是 |
|---|---|
| 「前面空一拍，从第 2 拍开始」 | `"1:0/8"` |
| 「beat 5 那两条 1/3 纵连」 | `"4:1/3"` 和 `"4:2/3"` |
| 「beat 6 的四押长条」 | 头 `"5:0/4"`，尾 `"5:1/4"` |

所以：

- 用户说「**beat 5**」，你在 patch 里要写 `"4:..."`。
- 你 dump 出来 `"beat": "4:1/3"`，和用户说的「在 beat 5」**是同一件事**，不是数据错了。

⚠️ `bar:numerator/denominator` 里的**分子不是「第几拍」**，而是这一小节按 `denominator` 切分后的第几格。
所以别拿分子去和用户说的 beat 比 —— 先按 `bar` 对齐（`bar` = 用户说的 beat − 1），再用分子定位小节内的位置。

> 这条曾经造成过一次真实的排查误判：界面上属性面板写 4、刻度栏写 5，被当成 bug 报过。
> 最后结论是**刻度栏对**（它和 Malody 一致），现在界面这两处都显示 5。
> 也就是说：**界面已经统一成「从 1 数」，只有文件和 JSON 还是「从 0 数」。**

---

## 3. `lumatool` 怎么用

```bat
lumatool\lumatool.exe help
lumatool\lumatool.exe dump  "<谱面.mc>" [--compact]
lumatool\lumatool.exe write "<谱面.mc>" --from <patch.json> [--dry-run]
lumatool\lumatool.exe write "<谱面.mc>" --from -        &rem  patch 从 stdin 读
```

### 契约（很重要）

- `dump` 的输出**就是** `write` 的输入 —— 同一个 JSON 形状，dump 出来改一改可以直接喂回去。
- patch 里**出现了的类别整体替换，没出现的类别原样不动**。
  五种类别：`notes` / `drafts` / `groups` / `presets` / `annotations`（另有单值 `activePreset`，规则见下）。
  所以只改一类时，**patch 里就只写那一类**，不要整份 dump 回写。
- `activePreset` 是**单值**：写了就改（正整数 = 指定预设，`0` = 清空），不写就不动。
- `timing` 是**只读**的（dump 会给你看，write 不接受）。
- `write` 只能改**已经存在**的 `.mc`；**新建谱面、导入音频要回编辑器界面做**。
- 改 `notes` / `drafts` 时，会先把原文件备份成 `<谱面.mc>.bak-<时间戳>`。
- `write` 结束会**回读文件**核对（不信任写入路径）。**看到非零退出码 = 没写成功**，不要当成功。
- 加 `--dry-run` 时**一个字节都不会写**。

### JSON 形状

```json
{
  "notes": [
    { "lane": 0, "beat": "23:0/4", "group": 2, "volume": 100 }
  ],
  "drafts": [
    { "column": 1, "beat": "23:0/4", "group": 7, "volume": 100 }
  ],
  "groups": [
    { "id": 2, "name": "底鼓", "color": "", "parentId": null }
  ],
  "activePreset": 1,
  "presets": [
    { "id": 1, "name": "按音轨", "groupIds": [2, 3], "assignments": [
      { "lane": 0, "beat": "23:0/4", "group": 2 },
      { "lane": 1, "beat": "23:0/4", "group": 2 }
    ] }
  ],
  "annotations": [
    { "id": 1, "text": "这里左手是阶梯", "anchorBeat": "23:0/4",
      "notes": [ { "lane": 1, "beat": "23:0/4" } ] },
    { "id": 2, "text": "额外轨道上补的音", "anchorBeat": "24:0/4",
      "notes": [ { "lane": 5, "beat": "24:0/4", "isDraft": true },
                 { "lane": -3, "beat": "25:0/4", "isDraft": true } ] }
  ]
}
```

- `beat` / `endBeat` / `anchorBeat` 写法都是 `bar:numerator/denominator`，也接受小数（`"2.25"`）。
- `lane` 是 **0-based**（界面上的「轨道 1」= `lane 0`）。
- `drafts` 是 ProEditor 那条额外轨道的 note；`column` 相对第一条正式轨，
  所以 `column 0` 就在 `lane 0` 底下（界面上显示成 `D:0`）。
- ⭐ **批注也能挂在额外轨道的 note 上**：此时 `annotations[].notes[]` 里写
  `"isDraft": true`，并且 `lane` 那一格装的是 **`drafts` 用的那个 `column`**
  （可以负、可以 ≥ keyCount，与正式 lane 是两套坐标）：
  `{"lane": 5, "beat": "24:0/4", "isDraft": true}` 指向 `column 5` 的草稿 note。
  **省略 `isDraft` = 正式轨**，所以老 patch、老 dump 的形状完全不变；
  dump 里正式键不会带这个字段，草稿键才带。
- `group` 是分组号；`0` 表示「未分组」，没有对应的 `groups` 条目。
- `groups[].parentId` 是「分组的分组」，可选；不做层级时留 `null`。
- `groups[].retired` = **这个分组在编辑器里被「解散」过，撤销还没把它带回来**：
  它的 note 已经归 0、任何预设的 `groupIds` 里都没有它，但**名字 / 颜色 / 层级还留着**，
  因为「解散」只把 note 写进谱面（那半边进撤销栈），分组本身记在编辑器这边（不进撤销栈）——
  名字删掉的话，用户按 Ctrl+Z 就只能拿回一堆 note 和一个叫 `Group 4` 的空壳。
  **省略 = `false`**，所以老 patch 的形状不变；dump 里只有真的 retired 才写这个字段。
  你**不要**为了「清理」把它删掉 —— 那正是它存在的理由。
- ⚠️ **值为 `null` 的字段在 dump 里直接不出现**（`endBeat` / `sound` / `parentId` / `activePreset` …）。
  写 patch 时可以照写 `null`（读作「没有」）；反过来，**省略某个字段 = 保持原值**，
  想清空 `sound` 就写 `""`。
- `chart` / `metadata` / `timing` 三项是 dump 给你的上下文，`write` 不接受。

### ⚠️ 分组预设是「一整套分组方案」，不是「装分组的口袋」

`.mc` 里每个 note **只有一个 `group` 整数**，所以任何时刻屏幕上只有一套分组生效。
于是：

- **`notes[].group` 是「当前生效那一套」的答案**，`activePreset` 说明它属于哪个预设（`null` = 不归属任何预设）。
- `presets[].assignments` 是**那个预设自己的完整对照表**：`(lane, beat) → group`。
  没被列出来的 note，在这个预设下就是**未分组** —— 缺席即 0，不需要写 `"group": 0` 的行。
- `presets[].groupIds` 是**那个预设自己有哪些分组**，也就是选中它时右侧分组列表显示哪些。
  一个分组属于「做它的时候正在用的那个预设」——所以「按音轨」里新建的分组不会出现在「按手感」里。
  - 写 patch 时 **`groupIds` 可以省略**：省略 = 交给 `assignments`（表里用到的分组自动算进名单，
    因为一个装着 note 的分组不可能不出现在列表上）。
  - 写了就按你写的算，但仍会补上 `assignments` 用到的那些 id。
  - ⚠️ 名单只是「列表默认显示哪些」，**不是「哪些分组存在」**：一个分组只要还有 note 带着它
    （**草稿 note 也算**），编辑器就一定会把它列出来 —— 行在、它的 note 却在屏上，是丢谱的成因。
- **同一个 note 在不同预设里可以有不同答案**，这是两套方案的意义所在，不是冲突。
  冲突只有一种：**同一个预设里同一个 `(lane, beat)` 出现两次**（会按先出现的算）。
- `activePreset` 的写法：正整数 = 指定该预设；`0` = 清空（不属于任何预设）；**这一项不写 = 保持原样不动**。
- ⚠️ 你改了 `presets` 之后，**`.mc` 里的 `group` 不会跟着变** —— 谁生效由编辑器决定。
  想真的按某个预设重新分组整张谱，要在编辑器里点那个预设标签（那是一次可 Ctrl+Z 的操作）。

---

## 4. 动手前必须知道的坑

1. **编辑器开着那张谱时，不要用 `lumatool` 写它。** 编辑器把谱面放在内存里，
   它下一次保存会把你的改动**整个覆盖掉**。→ 让用户先关掉那个 tab 或客户端，再写。
2. **note 的身份是 `(lane, beat)`，不是 id。** `ChartNote.Id` 是每次运行新生成的 GUID，
   **不落盘**，引用 note 一律用 `(lane, beat)`。批注里的 `notes` 就是这个格式。
   额外轨道上的草稿 note 同理，只是把 `lane` 换成 `column` 并写上 `"isDraft": true`
   （见第 2 节的那条 ⭐），所以完整身份其实是 `(isDraft, 列, beat)`。
3. **hold note（有 `endBeat` 的）移动时要把 `endBeat` 一起移**，否则长度会变。
4. **越界数据会被静默丢弃**，所以 `lumatool` 会直接拦你：
   `lane` 必须在 `0 .. keyCount-1`；`beat` 不能为负；`draft` 的 `column` 会被夹到 `[-64, keyCount+63]`。
   写之前先 `dump` 看一眼 `keyCount`。
5. **分组预设是整套方案，批注预设是显示筛选 —— 两边方向相反。**
   - 分组预设：`presets[].assignments` 是 `(lane, beat) → group` 的**完整对照表**，
     `presets[].groupIds` 是这套方案**自己有哪些分组**（切换预设时右侧列表就换成它）。
     同一个 note 在不同预设里可以有不同 group（这正是两套方案的意义）；
     同一个预设里同一个 `(lane, beat)` 写两次只会按第一次算。
   - 批注预设：`lumatool` **读写不到**（见第 5 节），它只决定「哪些批注显示在屏幕上」，不动任何 note。
6. **分组 / 批注元数据是按谱面的「绝对路径」索引的。** 谱面一旦换位置
   （改名目录、复制到别处、换机器），这些元数据就读不出来了 —— 数据还在 JSON 里，只是对不上号。
   要搬走它们，**用编辑器界面的「导出存档 / 导入存档」**，不要手工改 `chart-group-catalog.json`。
7. **未知字段会原样保留**，所以你改写谱面不会吃掉别的工具写进去的字段，可以放心。
8. **这是非官方构建**：客户端连的是官方服务器 `https://api.lumachart.cc/`。
   本构建的问题不要当官方问题上报。

---

## 5. `lumatool` 覆盖不到的地方

| 功能 | 现状 |
|---|---|
| **切换分组预设（= 按另一套方案重新分组整张谱，并把分组列表换成那套自己的）** | `lumatool` 能写整套方案（`presets[].assignments` + `presets[].groupIds`）让编辑器下次读到它；**真正把某套方案套到谱面上、并压成一次可撤销操作，要在编辑器里点预设标签** |
| **在界面上新建 / 「使用」一个分组时自动归进当前预设** | 这是界面的行为。`lumatool` 想达到同样效果，就自己把那个 id 加进对应预设的 `groupIds` |
| **批注预设（决定哪些批注显示）** | `lumatool` 只读写批注本身，**不读写它属于哪个批注预设**。要动预设得在界面上点 |
| **编辑器存档（导出 / 导入）** | 把「分组名/颜色/层级 + 分组预设 + 每条 note 的分组号 + 批注与批注预设 + ProEditor 轨道」打包成一个 `.luma-archive.json`。**只有编辑器界面能做**（在「分组管理」面板底部） |
| 新建谱面 / 导入音频 / 难度分析 / 导出 `.mcz` | 只能在编辑器界面里做 |
| 时间记录（BPM / Delay / Effect） | `dump` 能看，`write` 改不了 |

---

## 6. 推荐的工作流

1. **先 `dump`**，看清当前状态再动手（不要凭记忆改谱）。
2. 想清楚要改**哪一类**，patch 里**只写那一类**。
3. 先加 `--dry-run` 跑一次，看它说要变什么；确认无误再去掉。
4. 真正写入后再 `dump` 一次，和你预期的对一遍。
5. 写入前确认用户**已经关掉客户端**；写完再让他打开。
