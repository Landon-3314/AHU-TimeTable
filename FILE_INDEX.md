# 文件索引

> 简洁实用的项目文件索引，包含文件路径、负责功能、关键类/函数、常见改动入口

## 核心目录结构

```
lib/
├── core/           # 路由、主题引擎、常量
├── models/         # 数据模型
├── providers/      # 状态管理
├── screens/        # 页面
├── services/       # 核心服务
└── widgets/        # 可复用组件
```

---

## 核心入口

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/main.dart` | 应用启动入口 | `main()`, `_initAppSafely()`, `_MainApp` | 初始化流程、Provider 注册 |
| `lib/widgets/timetable_app.dart` | MaterialApp 配置 | `TimetableApp` | 主题、路由、本地化 |

---

## 核心配置 (core/)

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/core/app_routes.dart` | 路由定义 | `AppRoutes`, `onGenerateRoute()` | 新增/修改页面路由 |
| `lib/core/app_theme.dart` | 主题引擎 | `AppTheme.light()`, `AppTheme.dark()` | 明暗主题样式 |
| `lib/core/app_theme_tokens.dart` | 主题 Token | `AppThemeTokens` | 颜色、间距、字体规范 |
| `lib/core/app_colors.dart` | 颜色定义 | `AppColors` | 调色板 |
| `lib/core/app_constants.dart` | 全局常量 | `AppConstants` | 节次、周次等业务常量 |
| `lib/core/app_page_transitions.dart` | 页面转场动画 | `AppPageTransitions` | 转场效果 |

---

## 数据模型 (models/)

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/models/course.dart` | 课程模型 | `Course`, `sessionKey`, `copyWith()` | 课程字段扩展 |
| `lib/models/event.dart` | 单次日程模型 | `Event` | 日程字段扩展 |
| `lib/models/semester.dart` | 学期配置 | `Semester` | 学期字段 |
| `lib/models/clock_time.dart` | 时间点模型 | `ClockTime` | 时间表示 |
| `lib/models/time_slot.dart` | 时间段模型 | `TimeSlot` | 时间段定义 |
| `lib/models/academic_credential.dart` | 教务凭据 | `AcademicCredential` | 凭据字段 |
| `lib/models/update_manifest.dart` | 更新清单 | `UpdateManifest`, `UpdateAsset` | 版本信息结构 |
| `lib/models/timetable_view_data.dart` | 课表视图数据 | `TimetableViewData` | 视图状态 |

---

## 状态管理 (providers/)

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/providers/course_provider.dart` | 课程/日程状态管理 | `CourseProvider`, `sortedCourseGroups` | 增删改查课程、导入逻辑 |
| `lib/providers/settings_provider.dart` | 全局设置状态 | `SettingsProvider`, `t()` | 主题、学期、提醒等设置 |
| `lib/providers/timetable_view_provider.dart` | 课表视图状态 | `TimetableViewProvider` | 周次、星期切换 |

---

## 页面 (screens/)

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/screens/main_scaffold.dart` | 主脚手架 (底部导航) | `MainScaffold` | Tab 切换、启动提示 |
| `lib/screens/timetable_page.dart` | 课表主页面 | `TimetablePage` | 课表展示、手势交互 |
| `lib/screens/settings_page.dart` | 设置页面 | `SettingsPage` | 设置项分组 |
| `lib/screens/add_course_page.dart` | 新增/编辑课程 | `AddCoursePage` | 课程表单字段 |
| `lib/screens/import_course_page.dart` | 教务导入页面 | `ImportCoursePage` | WebView 抓取、解析 |
| `lib/screens/reschedule_course_page.dart` | 调课页面 | `RescheduleCoursePage` | 调课逻辑 |
| `lib/screens/exam_overview_page.dart` | 考试概览 | `ExamOverviewPage` | 考试列表展示 |
| `lib/screens/academic_account_page.dart` | 教务账号管理 | `AcademicAccountPage` | 登录、凭据管理 |
| `lib/screens/semester_time_settings_page.dart` | 学期时间设置 | `SemesterTimeSettingsPage` | 起止日期、节次时间 |
| `lib/screens/theme_settings_page.dart` | 主题设置 | `ThemeSettingsPage` | 强调色、深色模式 |
| `lib/screens/reminder_settings_page.dart` | 提醒设置 | `ReminderSettingsPage` | 提醒开关、时间 |
| `lib/screens/period_start_time_settings_page.dart` | 节次时间设置 | `PeriodStartTimeSettingsPage` | 每节课开始时间 |
| `lib/screens/developer_diagnostics_page.dart` | 开发者诊断 | `DeveloperDiagnosticsPage` | 调试工具 |

---

## 核心服务 (services/)

### 存储与数据

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/services/storage_service.dart` | SharedPreferences 封装 | `StorageService` | 存储 key、读写方法 |
| `lib/services/external_data_backup_store.dart` | 外部数据备份 | `ExternalDataBackupStore` | 备份/恢复逻辑 |
| `lib/services/corrupt_row_diagnostic_store.dart` | 损坏数据诊断 | `CorruptRowDiagnosticStore` | 数据修复 |

### 课表解析与调度

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/services/schedule_parser_service.dart` | HTML 解析课程 | `ScheduleParserService.parse()` | 解析正则、字段映射 |
| `lib/services/schedule_html_extractor.dart` | HTML 提取 | `ScheduleHtmlExtractor` | 提取逻辑 |
| `lib/services/schedule_calculator.dart` | 周次计算 | `ScheduleCalculator` | 周次推导 |
| `lib/services/schedule_plan.dart` | 调度计划 | `SchedulePlan` | 提醒时间计算 |
| `lib/services/course_conflict_policy.dart` | 冲突策略 | `CourseConflictPolicy` | 冲突处理规则 |
| `lib/services/timetable_view_data_service.dart` | 课表数据服务 | `TimetableViewDataService` | 视图数据构建 |
| `lib/services/timetable_navigation_controller.dart` | 课表导航控制 | `TimetableNavigationController` | 周次跳转逻辑 |

### 提醒与通知

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/services/native_alarm_service.dart` | 原生闹钟 (Android) | `NativeAlarmService` | MethodChannel 通信 |
| `lib/services/local_notification_service.dart` | 本地通知 | `LocalNotificationService` | 通知调度 |
| `lib/services/persistent_course_reminder_manager.dart` | 常驻通知管理 | `PersistentCourseReminderManager` | 前台通知 |
| `lib/services/permission_service.dart` | 权限管理 | `PermissionService` | DND、通知权限 |
| `lib/services/system_schedule_manager.dart` | 系统调度管理 | `SystemScheduleManager` | 静音/恢复调度 |

### 教务系统集成

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/services/academic_credential_service.dart` | 凭据存储 | `AcademicCredentialService` | 加密存储 |
| `lib/services/academic_auto_login_service.dart` | 自动登录 | `AcademicAutoLoginService` | 登录流程 |
| `lib/services/academic_daily_auto_import_service.dart` | 每日自动导入 | `AcademicDailyAutoImportService` | 后台同步 |

### 应用更新

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/services/update_check_service.dart` | 更新检查 | `UpdateCheckService` | 版本比对逻辑 |
| `lib/services/update_download_service.dart` | 下载安装 | `UpdateDownloadService` | 下载、安装流程 |
| `lib/services/update_http_client.dart` | HTTP 客户端 | `UpdateHttpClient` | 网络请求 |
| `lib/services/update_mirror_urls.dart` | 镜像源配置 | `UpdateMirrorUrls` | 镜像 URL |
| `lib/services/app_update_platform.dart` | 平台适配 | `AppUpdatePlatform` | 平台差异处理 |

### 其他服务

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/services/app_services.dart` | 服务聚合入口 | `AppServices.init()`, `refreshSchedules()` | 服务初始化、提醒刷新 |
| `lib/services/long_screenshot_service.dart` | 长截图服务 | `LongScreenshotService` | 截图捕获 |
| `lib/services/app_storage_platform.dart` | 存储平台适配 | `AppStoragePlatform` | 平台差异 |

---

## UI 组件 (widgets/)

### 课表组件 (widgets/timetable/)

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/widgets/timetable/timetable_grid.dart` | 课表格子 | `TimetableViewGrid` | 格子布局、样式 |
| `lib/widgets/timetable/course_card.dart` | 课程卡片 | `CourseCard` | 卡片样式、点击事件 |
| `lib/widgets/timetable/event_card.dart` | 日程卡片 | `EventCard` | 日程展示 |
| `lib/widgets/timetable/week_selector.dart` | 周次选择器 | `WeekSelector` | 周次切换 UI |
| `lib/widgets/timetable/course_overview_panel.dart` | 课程总览面板 | `CourseOverviewPanel` | 课程列表 |
| `lib/widgets/timetable/timetable_detail_sheets.dart` | 详情弹窗 | `TimetableDetailSheets` | 课程/日程详情 |
| `lib/widgets/timetable/holiday_list_view.dart` | 假期列表 | `HolidayListView` | 假期展示 |

### 通用组件 (widgets/common/)

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/widgets/common/app_ui.dart` | 通用 UI 元素 | `AppSpacing`, `AppSectionTitle` | 间距、标题样式 |
| `lib/widgets/common/app_wheel_pickers.dart` | 滚轮选择器 | `AppWheelPickers` | 时间/数字选择 |
| `lib/widgets/common/capsule_multi_select.dart` | 胶囊多选 | `CapsuleMultiSelect` | 周次多选 |
| `lib/widgets/common/guided_tour_overlay.dart` | 新手引导 | `GuidedTourOverlay` | 引导步骤 |

### 其他组件

| 文件 | 功能 | 关键类/函数 | 改动入口 |
|------|------|------------|----------|
| `lib/widgets/semester_initialization_guard.dart` | 学期初始化守卫 | `SemesterInitializationGuard` | 未初始化提示 |
| `lib/widgets/semester_start_date_dialog.dart` | 学期开始日期弹窗 | `SemesterStartDateDialog` | 日期选择 |
| `lib/widgets/update_prompt.dart` | 更新提示 | `UpdatePrompt` | 更新弹窗 |
| `lib/widgets/long_screenshot_scroll_capture.dart` | 长截图滚动捕获 | `LongScreenshotScrollCapture` | 截图逻辑 |
| `lib/widgets/settings/settings_section.dart` | 设置分区 | `SettingsSection` | 设置项布局 |
| `lib/widgets/settings/class_auto_mute_switch.dart` | 自动静音开关 | `ClassAutoMuteSwitch` | 静音设置 |
| `lib/widgets/settings/reminder_settings_section.dart` | 提醒设置分区 | `ReminderSettingsSection` | 提醒配置 |
| `lib/widgets/daily_academic_auto_import_host.dart` | 每日自动导入宿主 | `DailyAcademicAutoImportHost` | 自动导入触发 |

---

## 测试文件 (test/)

| 目录 | 测试范围 |
|------|----------|
| `test/models/` | 数据模型单元测试 |
| `test/providers/` | 状态管理单元测试 |
| `test/services/` | 服务层单元测试 |
| `test/core/` | 核心配置测试 |
| `test/widgets/` | Widget 测试 |

---

## 配置文件

| 文件 | 功能 |
|------|------|
| `pubspec.yaml` | 依赖配置、版本号 |
| `analysis_options.yaml` | Dart 分析规则 |
| `update.json` | 应用更新清单 |
| `AGENTS.md` | 开发文档 |
| `README.md` | 项目说明 |

---

## 常见改动场景速查

### 新增课程字段
1. `lib/models/course.dart` - 添加字段
2. `lib/services/storage_service.dart` - 存储 key
3. `lib/screens/add_course_page.dart` - 表单 UI
4. `lib/services/schedule_parser_service.dart` - 解析逻辑

### 修改课表样式
1. `lib/widgets/timetable/timetable_grid.dart` - 格子布局
2. `lib/widgets/timetable/course_card.dart` - 卡片样式
3. `lib/core/app_theme_tokens.dart` - 颜色/间距

### 新增设置项
1. `lib/providers/settings_provider.dart` - 状态字段
2. `lib/services/storage_service.dart` - 持久化
3. `lib/screens/settings_page.dart` - UI 展示

### 修改提醒逻辑
1. `lib/services/schedule_plan.dart` - 时间计算
2. `lib/services/native_alarm_service.dart` - Android 闹钟
3. `lib/services/local_notification_service.dart` - 通知调度
4. `lib/services/persistent_course_reminder_manager.dart` - 常驻通知

### 新增页面
1. `lib/screens/` - 创建页面文件
2. `lib/core/app_routes.dart` - 注册路由
3. `lib/screens/main_scaffold.dart` - 如需底部 Tab

### 修改教务导入
1. `lib/services/schedule_parser_service.dart` - HTML 解析
2. `lib/screens/import_course_page.dart` - WebView 交互
3. `lib/services/academic_auto_login_service.dart` - 自动登录
