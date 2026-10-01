# 进度节点 · TasksSteps

一个原生 iOS 任务管理 App（SwiftUI，纯本地存储，无网络、无第三方依赖）。

核心用法：**新建任务 → 把它拆成若干进度节点 → 手动勾掉一个节点，进度条就前进一格。**

---

## 1. 功能

| 功能 | 说明 |
| --- | --- |
| 任务列表 | 卡片式列表，每行显示标题、百分比、细进度条、`已完成/总数` 节点数、下一步、截止日期 |
| 顶部总览 | 圆环显示所有任务的整体节点完成率，以及已完结任务数 |
| 新建任务 | 填标题、备注、可选截止日期，并可在表单里一次性连续录入多个节点 |
| 批量加节点 | 详情页可一次粘贴多行文本，一行变一个节点 |
| 勾选推进进度 | 点节点任意位置即勾选/取消，进度条带动画前进，并记录完成时间 |
| 大进度条 | 详情页顶部：大百分比 + 18pt 渐变进度条，节点数 > 1 时进度条上带分段刻度 |
| 节点管理 | 增 / 删 / 改名 / 加备注 / 拖动排序（长按）/ 左滑删除 |
| 任务管理 | 编辑信息、复制任务、一键全部完成、一键重置进度、左滑删除 |
| 误删撤销 | 删除任务后底部弹出「撤销」，4 秒内可恢复 |
| 排序 | 手动顺序 / 按创建时间 / 按进度（未完成优先）/ 按截止日期 |
| 逾期提示 | 截止日期已过且未完成时显示橙色警告 |
| 持久化 | 自动存到 `Application Support/tasks.json`，切后台立刻落盘 |
| 适配 | 深色模式、动态字体、iPhone + iPad |

---

## 2. 目录结构

```
TasksSteps/
├── project.yml                      # XcodeGen 工程描述（工程文件由它生成）
├── .github/workflows/build-ipa.yml  # GitHub Actions：云端编译出未签名 IPA
├── scripts/build_ipa.sh             # 有 Mac 时本地一键出 IPA
├── TasksSteps/
│   ├── Info.plist
│   ├── App/TasksStepsApp.swift      # App 入口 + 场景生命周期落盘
│   ├── Models/TaskStore.swift       # Task / TaskNode 模型 + 增删改 + JSON 持久化
│   └── Views/
│       ├── Components.swift         # 进度条、进度环、勾选圈、配色
│       ├── TaskListView.swift       # 首页列表 + 总览卡 + 撤销条
│       ├── TaskDetailView.swift     # 详情页：大进度条 + 节点清单
│       └── TaskEditorSheet.swift    # 新建/编辑任务的表单
└── README.md
```

> 注意：Windows 上没有 Apple SDK，也编译不了 Swift/iOS，所以这个仓库里**只有源码**，`.ipa` 必须在 macOS 环境（本机 Mac 或 GitHub Actions 的 macOS runner）上编译出来。

---

## 3. 拿到未签名 IPA

### 方案 A：GitHub Actions（不需要 Mac，推荐）

1. 在 GitHub 新建一个仓库（Private 也行），把 `TasksSteps/` 里的**内容**推到仓库根目录：

   ```bash
   cd TasksSteps
   git init
   git add .
   git commit -m "feat: 进度节点 iOS App"
   git branch -M main
   git remote add origin git@github.com:<你的账号>/<仓库名>.git
   git push -u origin main
   ```

2. 推送后自动触发（也可以在仓库 **Actions → Build unsigned IPA → Run workflow** 手动触发）。

3. 等大约 3–6 分钟，进入这次 run 的页面，在底部 **Artifacts** 下载
   `TasksSteps-unsigned-ipa`，解压得到 `TasksSteps-unsigned.ipa` 和它的 sha256。

> 免费额度：GitHub 免费账号的 **Public 仓库 Actions 不限量**，Private 仓库每月 2000 分钟，一次构建约 4 分钟，够用很久。
> 这个 workflow 默认 `sign_mode=unsigned`：**完全不签名**，不做证书校验，专门给你后面自己重签。

### 方案 B：自己有 Mac

```bash
brew install xcodegen          # 只需一次
cd TasksSteps
chmod +x scripts/build_ipa.sh
./scripts/build_ipa.sh         # 产物：dist/TasksSteps-unsigned.ipa
```

也可以直接双击打开工程：

```bash
xcodegen generate --spec project.yml
open TasksSteps.xcodeproj
```

想先打个占位签名（某些重签工具更省事）：`SIGN_MODE=adhoc ./scripts/build_ipa.sh`

### 方案 C：Windows + 远程 Mac

用 MacinCloud / MacStadium 之类的云 Mac，把源码传上去，跑方案 B 的命令即可。

---

## 4. 在手机上装（重点：先重签）

`TasksSteps-unsigned.ipa` **不能直接安装**——iOS 只接受带有效签名的 App。所以你需要在安装前用它签名，这正是你要的那一步：

| 工具 | 平台 | 说明 |
| --- | --- | --- |
| **Sideloadly** | Win / Mac | 拖入 ipa + 填 Apple ID，自动重签并安装，最省事 |
| **AltStore / SideStore** | Win / Mac + 手机 | 装一次后可在手机上续签，免费账号 7 天自动续 |
| **ESign / 爱思助手 / Scarlet** | 手机 / Win | 用导入的证书直接重签 ipa |
| **TrollStore** | 手机 | 仅支持有 CoreTrust 漏洞的系统（iOS ≤ 16.6.1 等），可永久免签安装 |
| **Xcode** | Mac | 打开工程，填自己的 Team，直接 Run 到手机（Xcode 会自己签名，不需要 ipa） |

免费 Apple ID 的限制要知道：

- 证书 **7 天**过期，过期后 App 打不开，需要重新签（AltStore 可自动续签）
- 同时最多 **3 个**自签 App，每周最多注册 10 个 App ID
- 想 1 年有效期就要 99 美元/年的开发者账号，或用企业证书（有风险）

如果你有 `.p12` 证书 + `.mobileprovision` 文件想直接重签：

```bash
# 解包
unzip -o TasksSteps-unsigned.ipa -d work
# 重签（示例）
codesign -f -s "iPhone Distribution: Your Name" --entitlements ent.plist work/Payload/TasksSteps.app
# 重新打包
cd work && zip -qry ../TasksSteps-signed.ipa Payload
```

---

## 5. 代码里几个实现要点

- **进度计算**：`Task.progress = 已完成节点数 / 节点总数`，0 节点时为 0，进度条按此比例绘制；节点数 > 1 时叠一层分段刻度，视觉上「勾一个走一格」。
- **勾选交互**：整行可点（`onTapGesture`），走 `store.toggle(node:in:)`，同时写入/清空 `completedAt`，并用 `.spring` 动画驱动 `Capsule` 宽度变化。
- **持久化**：`TaskStore` 是单一 `ObservableObject`，改动后 `save()` 原子写入 JSON；场景进入后台时再兜底保存一次。
- **数据流**：SwiftUI + `@EnvironmentObject`，无第三方依赖，`project.yml` 里零 `packages`。

---

## 6. 想改什么改什么

| 想改 | 改哪里 |
| --- | --- |
| App 名字 | `project.yml` 的 `CFBundleDisplayName` + `TasksSteps/Info.plist` |
| Bundle ID | `project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER`（重签时可被覆盖，但建议改成你自己的） |
| 最低系统版本 | `project.yml` 的 `deploymentTarget`（低于 iOS 17 要替换 `ContentUnavailableView` 等 API） |
| 配色 | `Views/Components.swift` 的 `Theme` |
| 示例数据 | `Models/TaskStore.swift` 的 `sampleData`（删掉即可首次启动为空） |

---

## 7. 已知坑：工程格式比 Xcode 新

**症状**（Actions 的 `Build app` 那一步失败）：

```
xcodebuild: error: Unable to read project 'TasksSteps.xcodeproj'.
  Reason: The project 'TasksSteps' cannot be opened because it is in a
          future Xcode project file format (77).
Error: Process completed with exit code 74
```

**原因**：XcodeGen 2.44 起默认按最新的 Xcode 工程格式生成，写进 `project.pbxproj` 的
`objectVersion = 77`；而工作流当时把 Xcode **硬钉在 15.4**，它最高只认 60，看到 77 就直接
拒绝打开——连编译都没开始，所以错误出现在 `Build app` 而不是代码错误。

**处理**（两层保险）：

1. 工作流改成**选 runner 上装的最新 Xcode**，不再硬钉 15.4。新版 XcodeGen 写的格式，
   交给新版 Xcode 打开，两边版本对齐。
2. 生成工程后用 `scripts/normalize_project.py` 按当前 Xcode 版本自动决定是否需要把
   `objectVersion` 降到兼容值（Xcode 15 → 60，Xcode 14 → 56）。脚本是幂等的：
   工程格式本来就够新/够老时它原样放过、不做任何改动。

排查时看这两行日志就够了：

```
=== 生成的工程格式 ===
	objectVersion = 77;
=== 归一化后 ===
	objectVersion = 77，不超过 77，无需改动 ✓
```

如果你在本机 Mac 上遇到同样报错，手动跑一次即可：

```bash
python3 scripts/normalize_project.py TasksSteps.xcodeproj --auto
```

