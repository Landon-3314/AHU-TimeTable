# 安课 (Timetable)

一个本地优先的 Flutter 课程表应用，支持课程管理、教务系统导入与自动同步、单次调课、日程提醒、考试查询以及跨端长截图。当前以 Android 平台支持最为完整，同时支持跨多端运行。

## 功能特性

- **课表与日程管理**
  - 日视图、周视图双模式，课程与单次日程混合展示
  - 支持学期周切换与“假期中”模式
  - 支持手动新增、编辑、删除课程和单次日程
  - 支持单次调课功能（原课程移除该周次，生成新的单周次课程）
- **教务系统集成**
  - WebView 抓取教务系统 HTML 或使用教务账号体系登录
  - 支持保存教务账号凭据并实现每日后台自动同步
  - 智能解析冲突策略、自动过滤并覆盖旧的重复课程
  - 支持“考试概览”与查询功能
- **提醒与自动化**
  - 彻底抛弃旧版后台轮询，采用原生通道 (NativeAlarmService) 结合本地通知 (LocalNotificationService) 调度提醒
  - 支持 Android 上课自动静音/下课恢复 (通过原生精确闹钟与 DND 权限)
  - 持久化课程常驻通知 (Persistent Course Reminder)
  - 支持 Android 系统级长截图捕获
- **高级设置与扩展**
  - 外部数据本地备份与恢复能力
  - 完善的多主题引擎 (明暗模式、强调色配置)
  - 自定义学期起止、每天课程节次与时间段
  - 多镜像源的应用内自更新系统 (OTA Download & Install)

## 技术栈

- **框架**: Flutter
- **状态管理**: provider
- **存储**: shared_preferences, flutter_secure_storage
- **系统集成**: permission_handler, flutter_local_notifications, timezone, sound_mode, app_settings
- **网络与解析**: webview_flutter, html, http, cronet_http
- **其他**: crypto

## 项目结构

```text
lib/
  core/         路由、主题引擎、常量
  models/       Course, Event, Semester, AcademicCredential, UpdateManifest
  providers/    SettingsProvider, CourseProvider, TimetableViewProvider
  screens/      主脚手架、课表页、账号页、考试页、设置页等
  services/     教务同步、原生闹钟调度、自更新、存储、后台提醒等核心服务
  widgets/      可复用 UI 组件
```

## 本地开发

### 环境要求

- Flutter Stable 
- Dart SDK 版本满足 `pubspec.yaml` 中的 `sdk: ^3.11.3`
- Android Studio / Android SDK (针对主平台开发)
- JDK 17

### 当前平台情况

- Android：当前主目标平台，系统级能力（自动静音、原生闹钟提醒、常驻通知、长截图等）最完整。
- iOS / macOS / Linux / Windows / Web：已保留 Flutter scaffold 与核心 UI，部分底层受限功能采取安全降级 (no-op) 处理。
