# 安大课表

一个本地优先的 Flutter 课程表应用，支持课程管理、教务系统导入、单次调课、日程提醒，以及 Android 上课自动静音。

## 功能特性

- 课表展示
  - 日视图、周视图双模式
  - 课程与单次日程混合展示
  - 支持学期周切换与“假期中”模式
- 课程管理
  - 手动新增、编辑、删除课程
  - 课程详情页支持单次调课
  - 调课后会从原周次移除该次课程，并生成新的单周课程
- 导入能力
  - 通过 WebView 登录教务系统后抓取课表
  - 自动过滤重复课程
  - 重新导入时，如果课程安排变化，则以后导入的数据为准
- 提醒与自动化
  - 课前提醒
  - 单次日程提醒
  - Android 自动静音
  - Android 后台前台服务维持状态刷新
- 设置能力
  - 学期起始日期、总周数
  - 每天课程节次与时间段
  - 中英文切换
  - 本地数据清理

## 技术栈

- Flutter
- provider
- shared_preferences
- webview_flutter
- intl
- flutter_local_notifications
- flutter_background_service
- permission_handler
- html

## 项目结构

```text
lib/
  core/         路由、主题、常量、颜色
  models/       课程、日程、时间段等模型
  providers/    课程数据、设置状态
  screens/      页面层
  services/     导入、存储、提醒、后台服务
  widgets/      可复用 UI 组件
android/
  app/          Android 应用配置
.github/
  workflows/    GitHub Actions 工作流
```

## 本地开发

### 环境要求

- Flutter Stable
- Dart SDK 版本满足 `pubspec.yaml` 中的 `sdk: ^3.11.3`
- Android Studio / Android SDK
- JDK 17

### 启动步骤

```bash
flutter pub get
flutter run
```

### 常用构建命令

调试 APK：

```bash
flutter build apk --debug
```

按 ABI 拆分 APK：

```bash
flutter build apk --release --split-per-abi
```

产物通常位于：

```text
build/app/outputs/flutter-apk/
```

## GitHub Actions

仓库已提供一个 Android APK 构建工作流：

- 工作流文件：`.github/workflows/android-split-apk.yml`
- 触发方式：
  - 手动触发 `workflow_dispatch`
  - 推送标签 `v*`

它会执行与下面命令等价的构建：

```bash
flutter build apk --release --split-per-abi
```

并将以下 APK 作为 Actions artifact 上传：

- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

## 数据与行为说明

- 课程去重
  - 手动添加、编辑、自动导入都会进行重复判断
  - 当课程名、地点、教师一致，且星期相同、周次有交集、节次有重合时，视为重复课程
- 自动导入合并策略
  - 精确重复课程不会重复导入
  - 同一门课如果课程安排变化，则保留最新导入的安排
  - 单次调课产生的临时课程在重新导入后会被新导入的原始课表覆盖

## 当前平台情况

- Android：当前主目标平台，功能最完整
- iOS / macOS / Linux / Windows / Web：仓库已保留 Flutter scaffold，但自动静音、前台服务等能力主要面向 Android

