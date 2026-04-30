# 安课

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



## 当前平台情况

- Android：当前主目标平台，功能最完整
- iOS / macOS / Linux / Windows / Web：仓库已保留 Flutter scaffold，但自动静音、前台服务等能力主要面向 Android

