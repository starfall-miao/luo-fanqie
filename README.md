# 落·番茄

> 把时间种成番茄。

落·番茄是一款用 Flutter 写的本地优先番茄钟与待办应用。它把「专注计时、任务清单、专注统计」放在同一条时间线上：选一颗任务，专注一颗番茄，收获一段看得见的专注记录。

设计上采用暮色番茄配色——暖奶油、番茄红、落日琥珀与深梅色，配上一只缓慢生长的番茄表盘，希望专注这件事也能温柔一点。

<p align="center">
  <img src="docs/screenshots/01-focus-light.png" width="250" alt="专注页" />
  <img src="docs/screenshots/02-tasks.png" width="250" alt="任务页" />
  <img src="docs/screenshots/03-stats.png" width="250" alt="统计页" />
</p>

<p align="center">
  <img src="docs/screenshots/05-focus-dark.png" width="250" alt="深色专注页" />
  <img src="docs/screenshots/06-stats-full.png" width="250" alt="完整统计页" />
  <img src="docs/screenshots/07-task-editor.png" width="250" alt="新建任务" />
  <br />
  <sub>深色专注页 · 完整统计页 · 新建任务</sub>
</p>

---

## 功能

### 专注计时

- 经典番茄节奏：专注 / 小憩 / 长休息，默认 25 / 5 / 15 分钟，每 4 颗番茄进入一次长休息。
- 所有时长、长休息间隔和每日目标都可以在设置里调整。
- 基于「结束时间」计时，而不是逐秒累加；App 被系统冻结或切到后台，回到前台会立刻校准。
- 计时快照保存在本地，**冷启动也能恢复进行中的番茄**；如果回来时已经超时，会自动补记一颗番茄。
- 可绑定一颗待办任务，专注完成时自动累加该任务的番茄数。
- 自动开始休息 / 自动开始下一颗、系统通知、声音提醒、震动反馈均可独立开关。
- Android 端通过原生 `AlarmManager` 在计时结束时发系统通知，锁屏或应用进程被回收后仍能收到提醒；Android 13+ 首次开始计时时会请求通知权限。
- 完成专注会写入会话记录，并通过稳定的 session id 去重，避免恢复时重复计数。
- 跳过当前阶段不会计入番茄；长休息结束后自动重置一组番茄的计数。

### 任务清单

- 新任务支持标题、备注、预计番茄数、优先级、分类标签、截止日期。
- 按「未完成优先 → 高优先级优先 → 截止日期近优先」排序。
- 全部 / 待办 / 完成三种视图；完成状态、逾期状态和番茄进度一目了然。
- 左滑删除，支持撤销；点击任务即可编辑。
- 第一次打开会种下三颗轻量的示例任务，可以直接编辑或删除。

### 专注统计

- 今日专注分钟数、完成番茄数、连续专注天数与每日目标进度。
- 近 7 天专注分钟数柱状图。
- 最近 12 周专注热力图，每格代表一天，悬停或长按查看当天数据。
- 本周番茄、累计专注时长、最近专注记录。
- 统计只根据已完成的专注会话生成，跳过与中断都不会污染数据。

### 个性化

- 跟随系统 / 浅色 / 深色三种外观。
- 手机底部胶囊导航；宽屏（≥ 980dp）自动切换为侧边导航。
- 所有数据保存在本机，无账号、无后端、无网络请求。

---

## 快速开始

要求 Flutter **3.47+ / Dart 3.13+**。

```bash
cd luo_fanqie_app
flutter pub get

# 手机 / 模拟器
flutter run

# Web
flutter run -d chrome

# 构建 Web 版本
flutter build web --release
```

Android / iOS 安装包需要本机安装对应的 Android SDK 或 Xcode：

```bash
flutter build apk --release
flutter build ios --release
```

Linux 桌面依赖 GTK 开发环境，已生成 `linux/` 工程：

```bash
flutter build linux --release
```

---

## Android 安装包

当前最新构建：**1.1.0**（versionCode 2）

- 安装包：`dist/luo-fanqie-v1.1.0.apk`（通用 APK，含 arm64-v8a / armeabi-v7a / x86_64）
- 最低系统：Android 7.0（API 24），targetSdk 36
- 包名：`dev.luofanqie.luo_fanqie_app`
- 签名：release keystore（非 debug 签名），APK 使用 v2 签名方案
- 用 `adb install -r dist/luo-fanqie-v1.1.0.apk`，或把 APK 复制到手机点击安装
- SHA-256：`9b0c1af6e270161fc22997691542542a98bb15b0eda617ec2f9f06749d17be91`
- 注意：1.0.0 的本地 APK 是 debug 签名，与本版 release 签名不同；如果装过旧版，请先卸载再安装 1.1.0，之后即可用同一签名覆盖升级。

### 国内镜像构建

本工程已把 Gradle distribution 指向腾讯云镜像，并在 `android/settings.gradle.kts`、`android/build.gradle.kts` 中优先使用阿里云 Maven 镜像：

```bash
export LANG=C.UTF-8 LC_ALL=C.UTF-8       # 中文工程路径 + Java 必需
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PUB_HOSTED_URL=https://pub.flutter-io.cn

flutter build apk --release
```

本机 SDK 组件：Android SDK Platform 36 / 35、Build-Tools 36.0.0、NDK 28.2.13676358（r28c）、CMake 3.22.1、OpenJDK 17。`android/local.properties` 记录本机 SDK 与 Flutter 路径，不应提交到版本库。

### 发布签名

- `android/key.properties` 与 `android/app/luo-fanqie-release.jks` 是 **本机发布签名**，已加入 `.gitignore`。
- 升级已安装的应用必须使用同一个 keystore；请务必单独备份这两个文件，丢失后无法覆盖安装/升级。
- 如果克隆到没有 key.properties 的环境，Gradle 会自动回退到 debug 签名，方便本地构建。
- 若要在国内之外分发，建议重新用自己的开发者身份生成并保管 keystore。

---

## 测试

```bash
# 单元测试 + 组件测试（26 项）
flutter test

# 重新生成 docs 中的界面截图（需要本机有中文字体）
flutter test test/screenshots_test.dart \
  --update-goldens --dart-define=RUN_GOLDENS=true
```

覆盖内容：

- 任务 JSON 往返、排序、增删改、完成与撤销。
- 设置的夹取范围、持久化与损坏数据回退。
- 专注统计的按天聚合、去重、连续天数、周视图与热力图。
- 番茄钟完整专注、暂停恢复、跳过、长休息周期、自动开始、冷启动恢复与超时补记。
- 系统通知的编排：开始专注时安排、暂停/关闭开关时取消、自动休息时重新安排。
- 首页、开始/暂停、新建任务、任务选择器、统计页、设置页、深色切换。
- 360 × 740 小屏与 1280 × 800 宽屏布局。
- Web 构建已用无头 Chromium 做过冒烟验证：首帧正常、无控制台错误、计时初始值为 25:00。

---

## 项目结构

```
lib/
├── main.dart                     # 组装控制器与 Provider
├── app.dart                      # MaterialApp、主题与中文本地化
├── core/
│   ├── storage/                  # KeyValueStorage / SharedPreferences
│   ├── theme/                    # 配色、表面色 ThemeExtension、字体
│   └── utils/                    # 日期、时间与 ID 工具
├── features/
│   ├── home/                     # 底部导航 / 侧边导航外壳
│   ├── focus/                    # 专注页、番茄表盘、任务选择器
│   ├── tasks/                    # 任务模型、控制器、列表与编辑面板
│   ├── stats/                    # 专注记录、周图表、热力图
│   ├── settings/                 # 设置模型与页面
│   └── timer/                    # 番茄钟状态机与阶段视觉
└── shared/widgets/               # 背景、卡片、品牌番茄、通用组件
```

核心状态流：

```
TasksController ─┐
SettingsController ├─> PomodoroController ──> FocusSession ──> StatsController
                  ┘            │
                               └─ 完成番茄 → 任务番茄数 +1
```

所有控制器都是 `ChangeNotifier`，通过 `provider` 注入；存储层是可替换的 `KeyValueStorage`，测试使用内存实现，完全不需要平台插件。

---

## 计时语义

- **只有完整走完的专注阶段才会写入统计**。暂停、跳过、切换到其他阶段都不会产生记录。
- 记录以「计划时长」为准，例如 25 分钟专注记 25 分钟；会话 id 由结束时间与任务 id 生成，恢复计时时重复提交会被忽略。
- 长休息间隔按「已完成的专注数」计算；长休息结束后计数归零。
- 若冷启动时发现计时已经结束：补记原来的专注，再按设置决定是否自动开始休息；不会把等待期间算成额外番茄。

---

## 数据与隐私

- 数据通过 `shared_preferences` 保存在本机，键名统一使用 `luo_fanqie.*`。
- 不采集设备信息、不上传任务或专注记录、不含任何第三方统计 SDK。
- 设置页提供「清除已完成任务」与「清空专注记录」入口，二者都需要二次确认。
- 卸载应用会一并删除本地数据。

---

## 已知边界

- 系统通知目前只在 Android 端实现；iOS 与 Web 仍只依赖应用内提示，后续可以补 iOS 本地通知。
- Android 12+ 若未授予「精确闹钟」权限，提醒会退化为近似时间（仍会通知，但可能延迟几分钟）；可以在系统设置里为落·番茄开启精确闹钟。
- 声音提醒使用系统提示音（`SystemSound.alert`），暂未提供白噪音 / 环境音。
- 示例任务只在首次启动写入一次，删除后不会再自动出现。
- Web 端的数据保存在浏览器 localStorage，换浏览器或清除站点数据后会丢失。

---

## 设计与实现备注

- 番茄表盘、叶片番茄 Logo、背景光晕都是 `CustomPainter` 手绘，没有依赖图片素材；应用图标由 `tools/generate_icons.py` 生成（Pillow + numpy）。
- 图表使用 `fl_chart`；其余 UI 全部基于 Material 3 自定义，支持明暗主题、圆角玻璃卡片与响应式布局。
- 字体不随包体分发，使用系统中文字体回退链（PingFang SC / Noto Sans CJK SC / Microsoft YaHei / Droid Sans Fallback）；标题优先使用系统宋体类衬线字体，确保中文设备上的阅读质感。

---

## 版本

**1.1.0** · 2026-11

如果这颗番茄对你有一点用，就去种下今天的第一个 25 分钟吧。
