# 🔍 AnKe (安课) 全面代码审计报告

**项目:** Flutter + Android Kotlin 安徽大学课表应用
**规模:** 80个Dart文件 (~23,600行) + 11个Kotlin文件 (~3,500行) + 44个测试文件
**架构:** ChangeNotifier + Provider / Navigator 1.0 / Platform Channels

---

## ✅ 修复状态更新（2026-06-18）

> 本节是基于当前工作树的后续状态标记；下方原始审计描述保留作追溯。底部“路线图/最终统计”仍是原始报告统计，未重新核算，以本节和各标题中的状态为准。

### ✅ 已修复

| 编号 | 状态说明 |
|---|---|
| S-2 | CourseProvider 与 SettingsProvider 已补持久化失败回滚、再次通知 UI、SharedPreferences 写入检查/串行化、设置页错误提示与回归测试。 |
| S-3 | `add_course_page.dart`、`import_course_page.dart` 的已确认 async 后 UI 操作已补 `mounted` 检查。 |
| S-4 | 前台服务启动后先进入 foreground，再按窗口逻辑隐藏/停止，降低 Android 12+ 启动超时崩溃风险。 |
| S-5 | Kotlin `!!` 已改为安全回退。 |
| S-6 | `.gitignore` 已加入 `key.properties` / `**/key.properties`，且当前未发现相关文件被 Git 跟踪。 |
| H-2 | 报告中列出的主题设置、课程/日程删除和撤销等 fire-and-forget 路径已补错误捕获、提示或日志。 |
| H-4 / M-4 | `StorageService` 底层写入已串行化，并检查 `set/remove` 返回值，失败时抛错。 |
| H-1 | 已按职责拆分 `StorageService`、`SettingsProvider`、`TimetablePage`、`ImportCoursePage`、`MainActivity`，保留现有存储 key、路由、Provider API 与 MethodChannel 协议，并通过目标回归、analyze 与 Kotlin 编译验证。 |
| M-1 | 教务导入 URL 已改为显式主机白名单，不再接受任意 `*.ahu.edu.cn`。 |
| M-2 / N-24 | `_parseTime` 已改为 tryParse + 范围校验，损坏/越界时间整体回退 fallback。 |
| M-10 | 真实 Dart 空 `catch` 已补日志；跨域 iframe 的 JS catch 已加意图说明。 |
| N-20 / N-22 | main app 持有的 provider bundle 已增加显式 dispose，覆盖重试/退出生命周期。 |
| N-27 | 下载候选为空或失败时不再 null assert，改为可诊断错误与日志。 |

### ⚠️ 已缓解但未完全关闭

| 编号 | 状态说明 |
|---|---|
| H-3 | WebView 登录脚本中的密码变量已改为 `let`，填入后立即置空；但仍属于 JS 字面量注入方案，完整替代方案需专项设计。 |

### 🚫 误报 / 无需修复

| 编号 | 状态说明 |
|---|---|
| N-21 | Dart `switch` 语义不存在 C/Java 式 fall-through，该项复核为误报。 |
| N-28 | `_autoNavigateLoop` 的 `switch` 同样不存在隐式 fall-through，原报告按 C/Java 语义误判。 |

### ⏳ 仍未纳入本轮

S-1 更新清单签名/APK 完整签名校验、H-5 领域模型相等性、H-6 hash 统一，以及 N-19、N-23、N-25、N-26、N-29 之后的专项问题仍保留为后续项。

---

## 🔴 严重级别 (立即修复)

### S-1: 更新管线无签名验证 — 可被中间人攻击注入恶意APK ✅ 已验证
**严重性: HIGH** | 安全
- `update_check_service.dart` 从自定义域名 `update.277620035.xyz` 获取更新清单
- 清单本身无加密签名，SHA-256 来自同一不可信源
- 无证书固定 (cert pinning)，无APK签名验证 — `update_http_client_platform_io.dart:8-22` 使用默认 TrustManager，无 `network_security_config.xml`
- `REQUEST_INSTALL_PACKAGES` 权限允许直接安装APK

**攻击链:** 控制域名/DNS劫持 → 伪造清单 → 下载恶意APK → SHA-256匹配 → 安装木马
**建议:** ① 对更新清单用 Ed25519/RSA 签名，密钥硬编码在App内 ② 安装前验证APK的v2/v3签名 ③ 对更新域名实施证书固定

### S-2: Provider 层零 try/catch — 持久化失败导致静默数据丢失 ✅ 已修复（2026-06-18）
**严重性: HIGH** | 技术债 / 鲁棒性
- `course_provider.dart` (14个async方法) — 整个文件**零个** `try`/`catch`
- `settings_provider.dart` (~30个async方法) — **零个** `try`/`catch`，超过20处 fire-and-hope 模式
- 模式: 先改内存 → `notifyListeners()` → 再 `await saveXxx()`
- 如果磁盘满/文件损坏导致写入失败，内存已脏、UI已刷新，但数据未落盘
- 下次启动时用户修改全部丢失，无任何错误提示

**建议:** ① 持久化包裹 try/catch ② 失败时回滚内存状态并 re-notify ③ 向用户展示 Snackbar 错误提示

### S-3: async 后缺少 `mounted` 检查 — 导航离开时崩溃 ✅ 已修复（2026-06-18）
**严重性: HIGH** | 鲁棒性
- `import_course_page.dart:1161` — `await` 后 `Navigator.pop` 无 `mounted` 检查 ✅ 确认
- ~~`add_course_page.dart:596` — 已有 `mounted` 检查（L583）~~ ❌ 不准确，已存在
- `add_course_page.dart:819` — `await` 后 `setState` 无 `mounted` 检查 ✅ 确认
- `import_course_page.dart:947,966` — `await` 后 `setState` 无 `mounted` 检查 ✅ 确认

**触发:** 用户在异步操作进行中按返回键
**建议:** 所有 `await` 之后的 `setState`/`Navigator.pop` 前加 `if (!mounted) return;`

### S-4: Android 12+ 前台服务启动崩溃 ✅ 已修复（2026-06-18）
**严重性: HIGH** | 原生代码
- `TimetableForegroundService.kt:62-71`
- 通过 `ContextCompat.startForegroundService()` 启动后，如果 `isWithinDisplayWindow` 返回 false：
  - 调用 `hideForegroundNotification()` → `stopForeground(STOP_FOREGROUND_REMOVE)` + `stopSelf()` 
  - 返回 `START_NOT_STICKY`，**从未到达第74行的 `startForeground()`**
- Android 12+ 要求 5秒内必须调用 `startForeground()`，否则抛出 `ForegroundServiceDidNotStartInTimeException`
- 附加风险：`hideForegroundNotification()` 从 `updateNotification` 调用时会造成服务重启循环（因为 `START_STICKY` + `stopSelf()`）

**建议:** 在 `onStartCommand` 最前面立即调用 `startForeground()` 显示最小通知，之后再按需 `stopForeground`

### S-5: Kotlin `!!` 强制解包 — 潜在 NPE 崩溃 ✅ 已修复（2026-06-18）
**严重性: HIGH** | 原生代码
- `NativeAlarmTimePolicy.kt:71-72` — `rebaseTimestamp()` 返回 `Long?`，用 `!!` 强制解包
- 实际风险：`TodayCourseItem.startAtMillis` 和 `endAtMillis` 为 non-nullable `Long`，因此 `rebaseTimestamp` 的 `timestamp == null` 路径在此调用中不可达
- 但若数据类改为 nullable 或 `rebaseTimestamp` 语义变更，则立即 NPE

**建议:** 改用 `?: item.startAtMillis` 安全回退，或重构 `rebaseTimestamp` 为非空返回类型

### S-6: `key.properties` 未加入 `.gitignore` ✅ 已修复（2026-06-18）
**严重性: HIGH** | 安全
- `.gitignore` 中**没有** `key.properties` 条目
- `android/key.properties` 包含签名密钥路径和密码
- 若误提交，签名密钥泄露 → 任何人可签发冒名APK
- **建议:** 立即添加 `key.properties` 到 `.gitignore`，并验证是否已被 Git 追踪

---

## 🟠 高优先级 (尽快修复)

### H-1: 5个God Class — 可维护性严重下降 ✅ 已验证
**严重性: P1** | 技术债

| 类 | 行数 | 问题 |
|---|---|---|
| `StorageService` | 1,493 | 学期CRUD、课程持久化、30+设置项、备份同步、迁移全在一起 |
| `SettingsProvider` | 1,512 | 学期管理、时间配置、主题、通知、引导状态混合 |
| `TimetablePage` | 1,561 | 19个类混在一个文件，含可复用的 `PillTabSwitcher` |
| `ImportCoursePage` | 1,215 | WebView、凭据、自动登录、解析、冲突处理全在一个State |
| `MainActivity.kt` | 1,311 | 6个MethodChannel、权限、APK安装、滚动截屏全在一起 |

**建议:** 按职责拆分。`StorageService` → `SemesterStore` + `SettingsStore` + `CourseStore` + `BackupSyncService` + `MigrationService`

### H-2: fire-and-forget 异步调用丢弃异常 ✅ 已修复（报告列出的路径，2026-06-18）
**严重性: P0** | 技术债
- `theme_settings_page.dart:77-79` — `onTap: () => provider.changeThemePalette(...)` 不 await，`changeThemePalette` 是 `Future<void>`
- `timetable_detail_sheets.dart:143-173` — `unawaited(Future<void>.delayed(...).then((_) async { final removed = await courseProvider.removeCourse(course); ... }))` 删除操作完全无错误处理
- `timetable_detail_sheets.dart:335-367` — 同样模式用于 `deleteEvent`

**建议:** 用 async handler 包裹或 `unawaited(future.catchError(...))` 记录错误

### H-3: 密码明文注入 WebView JavaScript 上下文 ⚠️ 已缓解（2026-06-18）
**严重性: MEDIUM** | 安全
- `academic_auto_login_service.dart:47-54` — `jsonEncode(password)` 直接注入全局 JS 作用域
- 变量使用 `const` 声明，在 IIFE 词法作用域内不可删除或重新赋值
- 如果学术网站页面含第三方脚本，在其执行上下文中密码持续存在
- `jsonEncode` 对字符串仅做 JSON 转义（如引号），不提供加密保护

**建议:** ① 改用 `let` + 立即置null ② 最好用 WebView platform channel 设置表单值，避免JS注入

### H-4: SharedPreferences 并发写入无序列化 ✅ 已修复（2026-06-18）
**严重性: P1** | 技术债 / 鲁棒性
- 快速连续操作 (如先删除再添加课程) 触发独立的 `await saveXxx()` 调用
- SharedPreferences 非事务性，最终磁盘状态取决于哪个写入最后完成

**建议:** 对持久化写入加队列或防抖机制

### H-5: 领域模型无 `==` / `hashCode` ✅ 已验证
**严重性: P2** | 技术债
- `Course`、`Event`、`Semester`、`ClockTime`、`TimeSlot` 全部使用默认对象引用相等
- `List.contains()`、`Set` 操作、测试 `expect()` 全部可能误判
- `ClockTime` 和 `TimeSlot` 在 `settings_provider.dart` 中被用于列表比较，尤其需要

**建议:** 添加 `==` 和 `hashCode`，或使用 `freezed` / `equatable`

### H-6: `_stableHash` 在3处重复实现，位掩码不一致 ⚠️ 修正（3处非4处）
**严重性: P1** | 技术债
- `course.dart:211-218` — FNV-1a: init `0x811c9dc5`, multiply `0x01000193`, mask `& 0xffffffff`, 返回 hex String
- `event.dart:127-134` — **完全相同**的 FNV-1a 实现
- `schedule_parser_service.dart:453-459` — **不同算法**: DJB2 变体，init `0`, `((hash << 5) - hash) + codeUnit`, mask `& 0x7fffffff`, `.abs()`, 返回 int
- ~~`schedule_plan.dart` — 无 hash 函数~~ ❌ 原报告有误

**关键问题:** 两种算法 + 两种位掩码 (`0xffffffff` vs `0x7fffffff`) + 两种返回类型 (hex String vs int) — 同一输入产生不同 hash → ID 不匹配
**建议:** 提取到 `lib/core/hash_utils.dart`，统一一个规范实现

---

## 🟡 中等优先级 (计划修复)

### M-1: WebView URL 允许列表使用后缀匹配 ✅ 已修复（2026-06-18）
**严重性: MEDIUM** | 安全
- `import_course_page.dart:1005-1012` — `host.endsWith('.ahu.edu.cn')` 接受任意子域名
- 显式白名单仅为 `{'wvpn.ahu.edu.cn', 'ahu.edu.cn'}`，其余任意 `*.ahu.edu.cn` 子域名均可通过
- 子域名接管攻击可能利用此漏洞

**建议:** 改为显式枚举已知教务系统主机名

### M-2: `settings_provider.dart` 的 `_parseTime` 使用 `int.parse` 无防护 ✅ 已修复（2026-06-18）
**严重性: MEDIUM** | 鲁棒性
- `settings_provider.dart:1138-1144` — `int.parse(parts[0])` 无 try/catch，无 `int.tryParse`
- 有趣的是 `_isValidTimeString` (L1222) 使用了 `int.tryParse`，但 `_parseTime` 本身未使用
- 被 getter 属性（`morningStartTime`, `afternoonStartTime`, `eveningStartTime`）直接调用 → 存储损坏时在 `build()` 中崩溃

**建议:** 改用 `int.tryParse` + 兜底默认值

### M-3: `NativeAlarmScheduler` 调度失败静默吞掉异常 ⚠️ 部分修正
**严重性: MEDIUM** | 鲁棒性
- `native_alarm_service.dart:253-256` — `catch(e) { debugPrint(...); }`
- **修正:** 降级链比描述更完整 — 三个安全调度方法形成逐级降级链:
  `setAlarmClockSafely` → `setExactAllowWhileIdleSafely` → `setInexactAllowWhileIdleSafely`
- 降级链全部失败后确实**无用户反馈**（仅 `debugPrint`），用户不知道提醒功能已失效

**建议:** 返回成功/失败状态，UI层展示提示

### M-4: SharedPreferences 返回值未检查 ✅ 已修复（2026-06-18）
**严重性: MEDIUM** | 鲁棒性
- `storage_service.dart` 所有 `_setString`/`_setInt` 不检查 `setXxx()` 返回值
- 磁盘满时写入静默失败

**建议:** 检查返回值，失败时至少记录日志

### M-5: ROM 兼容性不完整 ✅ 已验证
**严重性: MEDIUM** | 原生代码
- `RomPermissionHelper.kt:10-24` 仅覆盖小米 (MIUI/HyperOS)、Vivo (FunTouchOS)、ColorOS (Oppo/OnePlus)
- 缺少: 华为 (EMUI/HarmonyOS: `com.huawei.systemmanager`)、三星 (One UI: `com.samsung.android.sm`)、魅族 (FlymeOS: `com.meizu.safe`)
- ColorOS 覆盖新版 OnePlus，但旧版 OxygenOS 未覆盖

**建议:** 补充华为、三星等自启动管理页面

### M-6: `AutoMuteScheduler` 使用不同 SharedPreferences 且未用设备保护存储 ✅ 已验证
**严重性: MEDIUM** | 原生代码
- `AutoMuteScheduler.kt:48` — 使用普通 `context.getSharedPreferences()` 而非 `createDeviceProtectedStorageContext()`
- 对比: `NativeStateStore.kt:251-259` 正确使用了设备保护存储
- Direct Boot 下数据不可访问，重启后音量恢复失败

### M-7: `AutoMuteScheduler.enableClassMute` 音量为0时不保存 ✅ 已验证
**严重性: MEDIUM** | 原生代码
- `AutoMuteScheduler.kt:49-61` — `if (currentMusic > 0)` 才保存，为0时跳过
- `AutoMuteScheduler.kt:78-85` — 恢复时 fallback 为最大音量的 40%（最小为1）
- 用户故意设的0会被恢复为40%

### M-8: `notificationPermissionResult` 在 Activity 重建时泄漏 ✅ 已验证
**严重性: MEDIUM** | 原生代码
- `MainActivity.kt:61` — `notificationPermissionResult` 是 Activity 实例字段
- 权限对话框显示期间 Activity 被销毁重建（旋转/多窗口），旧实例持有已销毁 Flutter engine 的 `MethodChannel.Result` 引用
- Flutter 侧 `await` 永久挂起

### M-9: 平台特定 import 无防护 ⚠️ 部分修正
**严重性: P0** | 技术债
- `import_course_page.dart:9` — 导入 `webview_flutter_android`，但在 L478 通过 `if (_controller.platform is AndroidWebViewController)` 做了运行时守卫
- `developer_diagnostics_page.dart:5-6` — 导入 `sound_mode`，在 L34 通过 `!kIsWeb && defaultTargetPlatform == TargetPlatform.android` 做了运行时守卫
- ~~`reminder_settings_page.dart` — 无 Android-only 包导入~~ ❌ 原报告有误
- 项目已有的 `platform.dart` / `platform_io.dart` 分离模式未被一致使用

### M-10: 42处静默 `catch (_)` + 12处完全空的 `catch (_) {}` ✅ 已修复真实空 catch（2026-06-18）
**严重性: P2** | 技术债
- ~42处 `catch(_)` 总览（原报告声称44处，接近）
- 12处完全空的 `catch(_){}`，精确命中:
  - `import_course_page.dart:864`
  - `academic_auto_login_service.dart:197,209,237,249`
  - `external_data_backup_store.dart:178,199,466`
  - `update_download_service.dart:72,98,215,247`
- 服务层无统一错误处理策略，生产环境问题几乎无法调试

**建议:** 禁止空 catch，至少 `debugPrint`；定义统一 `AppError` 层级

### M-11: 通知/闹钟时区处理
**严重性: MEDIUM** | 鲁棒性
- Dart侧 `local_notification` 的时区变更不会触发重新调度
- Kotlin侧通过 `BootRescheduleReceiver` 监听 `ACTION_TIME_SET`（与 `ACTION_TIME_CHANGED` 是同一定义）处理了原生闹钟
- 中国无夏令时，风险较低

---

## 🟢 低优先级 (随缘修复)

| # | 问题 | 类别 | 验证 |
|---|---|---|---|
| L-1 | `flutter_launcher_icons` 在 `dependencies` 而非 `dev_dependencies` | 技术债 | 未验证 |
| L-2 | 3个薄包装类无实际逻辑 (`PersistentCourseReminderManager` 15行, `SystemScheduleManager` 37行, `SemesterInitializationGuard` 6行) | 技术债 | 未验证 |
| L-3 | Kotlin `hasFutureWork` 扩展函数在两个文件重复定义 | 技术债 | 未验证 |
| L-4 | `AppStrings` 手写i18n (521行) 无编译时检查、无复数支持 | 技术债 | 未验证 |
| L-5 | 大量硬编码中文字符串绕过 `AppStrings` 本地化系统 | 技术债 | 未验证 |
| L-6 | `copyWith` 无法将可选字段清空为 null | 技术债 | 未验证 |
| L-7 | `Event.weeks` 未用 `List.unmodifiable` 包裹 ❌ **不准确** — `Event` 模型没有 `weeks` 字段，`Course` 模型已正确使用 `List<int>.unmodifiable(weeks)` | 技术债 | ❌ 无效 |
| L-8 | 时间戳ID生成理论碰撞风险 (`microsecondsSinceEpoch`) | 技术债 | 未验证 |
| L-9 | `app_routes.dart` 未知路由静默回退到主页 | 技术债 | 未验证 |
| L-10 | 生产Kotlin代码中大量 `Log.d("DND_DEBUG_NATIVE", ...)` 调试日志 ✅ 已验证 — `AutoMuteScheduler.kt` 中12+处, `AlarmReceiver.kt` 中8+处, `BootRescheduleReceiver.kt`, `NativeAlarmScheduler.kt`, `MainActivity.kt` 多处 | 安全 | ✅ |
| L-11 | 错误消息暴露内部实现 (`课表提取失败：$error`) ✅ 已验证 — `import_course_page.dart:957,978,1067,1144` 等多处暴露 `$e`/`$error` 给用户 | 安全 | ✅ |
| L-12 | 外部备份文件未加密写入外部存储 ✅ 已验证 — `external_data_backup_store.dart:30,117-118` 写入 `timetable-data.v1.json` 无加密，仅SHA-256防篡改 | 安全 | ✅ |
| L-13 | `NativeStateStore` JSON解析失败静默返回空列表 | 鲁棒性 | 未验证 |
| L-14 | `readSemesterStartDate` 未剥离时间分量 | 鲁棒性 | 未验证 |
| L-15 | `requestCodeFor` 使用 `String.hashCode()` 存在哈希碰撞风险 | 原生代码 | 未验证 |
| L-16 | `NativeAlarmScheduler` `setExactAndAllowWhileIdle` 回退到不精确闹钟可能导致恢复延迟 | 原生代码 | 未验证 |

---

## ✅ 代码优势 (值得保留的好模式)

1. **Provider 层大量 `mounted` 检查** ⚠️ **修正:** 实际13个页面文件（非16个），但全部都有 `mounted` 检查
2. **`flutter_secure_storage` 存储凭据** ✅ 验证 — 使用 v10.3.1，默认行为即 Android Keystore 加密
3. **全 HTTPS 强制** ⚠️ **修正:** 所有源URL为HTTPS，但无全局 WebView 强制，仅 `import_course_page` 有检查
4. **`key.properties` 已排除Git** ✅ **已补充** — `.gitignore` 现已加入 `key.properties` / `**/key.properties`；原问题已在 **S-6** 标记修复
5. **Clean Architecture 的纯逻辑层** ✅ 验证 — `ScheduleCalculator`、`CourseConflictPolicy`、`NativeMuteStatePolicy` 等无框架依赖
6. **Kotlin 策略对象分离** ✅ 验证 — 3个策略 object，各有一个测试文件
7. **47个测试文件** ✅ 修正 — 44个Dart测试 + 3个Kotlin测试 = 47个
8. **APK路径验证** 🆕 — `MainActivity.kt:650-657` 的 `isAllowedDownloadedApk()` 防止路径遍历攻击
9. **学术凭据安全存储** 🆕 — `academic_credential_service.dart` 使用 `FlutterSecureStorage`（Android Keystore 加密），密码未泄露到 SharedPreferences

---

## 📋 原始修复优先级路线图

> 状态说明：本表为原始报告路线图，已修复/误报项请以上方“修复状态更新”和各标题标记为准。

| 阶段 | 目标 | 工作项 |
|---|---|---|
| **Phase 1** (紧急) | 防崩溃/防数据丢失 | S-2 (Provider try/catch), S-3 (mounted检查), S-4 (前台服务), S-5 (!! 强制解包) |
| **Phase 2** (安全) | 堵安全漏洞 | S-1 (更新管线签名), H-3 (WebView密码注入), M-1 (URL白名单) |
| **Phase 3** (架构) | 降低技术债 | H-1 (拆God Class), H-6 (统一hash), H-5 (模型==), M-9 (平台import), M-10 (错误处理规范) |
| **Phase 4** (完善) | 提升质量 | M-5 (ROM兼容), H-2 (fire-and-forget), H-4 (写入序列化), L-1~L-16 |

---

## 🔬 第二轮多 Agent 交叉验证报告

**验证日期:** 2026-06-16 | **Agent 数量:** 4 (并行) | **覆盖领域:** 安全、Dart鲁棒性、Kotlin鲁棒性、通用代码质量

### 原始声明验证总览

| 级别 | 总数 | 确认准确 | 部分准确/需修正 | 不准确 | 准确率 |
|------|------|----------|----------------|--------|--------|
| 严重 (S) | 5 | 4 | 1 (S-3 一处已存在mounted) | 0 | 80% |
| 高优 (H) | 6 | 5 | 1 (H-6 3处非4处) | 0 | 83% |
| 中等 (M) | 11 | 10 | 1 (M-3 降级链存在) | 0 | 91% |
| 低优 (L) | 16 | 10 | 0 | 1 (L-7 Event无weeks) | 62% |
| 新增 (N) | 18 | 12 | 3 (N-15低风险,N-5描述不足) | 3 (N-9,N-17,N-18) | 67% |
| **合计** | **56** | **41** | **6** | **4** | **73%** |

### 需要修正的问题详情

| 编号 | 原始声明 | 实际情况 | 修正 |
|------|---------|---------|------|
| **S-3** | `add_course_page.dart:596` 无 mounted | L583 已有 `mounted` 检查守卫该路径 | 从列表中移除 |
| **H-6** | 4处重复 `_stableHash` | 仅3处（`schedule_plan.dart` 无hash函数），且 `event.dart` 与 `course.dart` 完全相同 | 修正数量和算法描述 |
| **M-3** | 完全静默吞异常 | 存在3级降级链：`setAlarmClock`→`setExactAndAllowWhileIdle`→`setInexactAllowWhileIdle` | 补充降级链描述 |
| **M-9** | `reminder_settings_page.dart` 有 Android-only 导入 | 无 Android-only 包导入 | 从列表中移除 |
| **L-7** | `Event.weeks` 未用 `List.unmodifiable` | `Event` 模型无 `weeks` 字段 | 标记为无效 |
| **N-9** | `clearAllData()` 是死代码 | 实际在 `settings_page.dart:389` 被调用 | 标记为不准确 |
| **N-17** | `TIME_CHANGED` 未在 Manifest 注册 | `ACTION_TIME_CHANGED` 和 `ACTION_TIME_SET` 是同一个字符串常量 `"android.intent.action.TIME_SET"`，Manifest 中已注册 | 标记为不准确 |
| **N-18** | `REQUEST_INSTALL_PACKAGES` 可能不需要 | Android 8+ 上 `FileProvider` 和 `REQUEST_INSTALL_PACKAGES` 服务于不同目的，两者都需要 | 标记为不准确 |

### 代码优势部分修正

| 声明 | 原结论 | 修正后 |
|------|--------|--------|
| 16个页面都有 mounted 检查 | 部分错误 | **13个页面文件，全部都有 mounted 检查** |
| key.properties 已排除Git | 原结论当时错误 | ✅ **已补充 `.gitignore`，见 S-6 修复状态** |
| 全 HTTPS 强制 | 部分正确 | 所有源URL为HTTPS，但无全局 WebView 强制 |

---

## 🆕 第二轮新发现问题

### 🔴 严重级别 (Critical)

#### N-19: `WebViewController` 未 dispose — 内存泄漏
**严重性: HIGH** | 内存
- **文件:** `lib/screens/import_course_page.dart:207,225,237-241`
- `_controller` (WebViewController) 在 `initState()` 创建，配置了 JS、zoom、navigation delegates
- `dispose()` 仅释放 `_studentIdController` 和 `_passwordController`，**完全未处理 `_controller`**
- WebView 持有原生渲染引擎和 JS 上下文 — 每次离开页面泄漏大量内存
- **建议:** 在 `dispose()` 中调用资源清理

#### N-20: 初始化重试时 ChangeNotifier 累积 — 内存泄漏 ✅ 已修复（2026-06-18）
**严重性: HIGH** | 内存
> 修复状态：main app 持有的 provider bundle 已在重试/退出生命周期显式 dispose。

- **文件:** `lib/main.dart:86-89, 20-61`
- `_retryInitialization()` 调用 `_initAppSafely()` 创建**新的** `SettingsProvider`、`CourseProvider`、`TimetableViewProvider`
- 旧实例通过 `ChangeNotifierProvider.value()` 传入但**不会被 dispose**
- 每次重试泄漏 3 个 ChangeNotifier + 所有 listener 闭包
- **建议:** 创建新 provider 前 dispose 旧实例

#### N-21: `import_course_page.dart` switch 功能性 Bug — timetable 自动导入同时执行 exam 导入 🚫 误报（2026-06-18）
**严重性: HIGH** | 功能正确性
> 复核状态：误报。Dart `switch` 不存在 C/Java 式隐式 fall-through，当前代码不会因缺少 `break` 自动执行下一个 `case`。

- **文件:** `lib/screens/import_course_page.dart:531-536`
- `case AcademicAutoAction.timetable:` 执行 `_runAutoTimetableImport()` 后**缺少 `break`**
- 导致 fall-through 到 `case AcademicAutoAction.exam:` → 额外执行 `_runAutoExamImport()`
- 用户选择课表导入时，考试数据也会被导入 → 数据污染
- **建议:** 在 case timetable 后加 `break;`

#### N-22: `ChangeNotifierProvider.value` 无生命周期 disposal — Provider 泄漏 ✅ 已修复（2026-06-18）
**严重性: MEDIUM** | 内存
> 修复状态：外部创建并通过 `.value` 注入的 provider 已由上层 bundle 负责显式 dispose。

- **文件:** `lib/main.dart:127-138`
- 三个 `ChangeNotifierProvider.value()` 包装了外部创建的 provider
- Flutter 文档明确：`ChangeNotifierProvider.value` **不调用** `dispose()`，调用者负责生命周期
- 整个 App 中无任何地方 dispose `SettingsProvider`、`CourseProvider`、`TimetableViewProvider`
- `_reminderScheduler` 回调和 `TimetableNavigationController` 的 `_settingsProvider` 引用保持对象图存活
- **建议:** 切换到 `ChangeNotifierProvider(create: ...)` 自动管理生命周期

#### N-23: `_stableHash` 的 DJB2 变体使用 `.abs()` 丢失信息
**严重性: MEDIUM** | 数据完整性
- **文件:** `lib/services/schedule_parser_service.dart:453-459`
- DJB2 变体：`((hash << 5) - hash) + codeUnit` 使用 `& 0x7fffffff` 后 `.abs()`
- 但 `& 0x7fffffff` 已保证非负（清除最高位），`.abs()` 是 no-op
- 真正的风险：仅使用 31-bit 空间，相比 FNV-1a 的 32-bit 碰撞概率更高
- 且与 `course.dart`/`event.dart` 的 FNV-1a 结果不可互操作

### 🟠 高优先级 (High)

#### N-24: `_parseTime` 在 getter 属性中崩溃 — 损坏数据的读取路径 ✅ 已修复（2026-06-18）
**严重性: MEDIUM** | 鲁棒性
> 修复状态：解析已改为 `tryParse` + 范围校验，非法/越界值整体回退 fallback。

- **文件:** `lib/providers/settings_provider.dart:1138-1144`
- `_parseTime`（不安全 `int.parse`）被 `morningStartTime`、`afternoonStartTime` 等 getter 直接调用
- 存储数据损坏后，仅读取 getter（如在 `build()` 中）即崩溃，而非仅在保存时
- `_isValidTimeString` (L1222) 使用 `int.tryParse` 但未被 `_parseTime` 利用

#### N-25: `loadCourseItems` 在 `onStartCommand` 中被调用 3 次 — 重复 I/O
**严重性: MEDIUM** | 性能 / Android
- **文件:** `TimetableForegroundService.kt:68-74`
- `scheduleVisibilityAlarms()` → `nextDisplayStartMillis()` + `currentDisplayWindow()` 各调 `loadCourseItems()`
- `buildNotification()` → `loadCoursesForLocalDay()` 再次调用
- 同一份 JSON 被从 SharedPreferences 读取/解析 3 次，在主线程同步执行
- **建议:** 在 `onStartCommand` 顶部计算一次，向下传递

#### N-26: `hideForegroundNotification()` 无条件 stopSelf 导致重启循环
**严重性: MEDIUM** | Android
- **文件:** `TimetableForegroundService.kt:104-108`
- `hideForegroundNotification()` 调用 `stopSelf()`
- 被 `updateNotification()` (L95-96) 调用时，服务以 `START_STICKY` 启动 → 系统立即重建服务
- 重建后 `onStartCommand` 再次检查 `isWithinDisplayWindow` → 仍为 false → 再次 `stopSelf` → **无限重启循环**
- **建议:** `updateNotification` 不应无条件 stopSelf；改用条件判断

#### N-27: `update_download_service.dart` null-assert 崩溃风险 ✅ 已修复（2026-06-18）
**严重性: MEDIUM** | 鲁棒性
> 修复状态：候选下载地址为空或全部失败时不再 `null` assert，改为抛出可诊断错误并记录日志。

- **文件:** `lib/services/update_download_service.dart:77`
- `Error.throwWithStackTrace(lastError!, lastStackTrace!)` — 如果 `candidateDownloadUris()` 返回空列表，循环从未执行，`lastError`/`lastStackTrace` 为 null
- `!` 抛出 NullCheckError 掩盖真实原因（"无可用下载URI"）
- **建议:** 在 assert 前检查 null：`if (lastError == null) throw StateError('No download URIs')`

#### N-28: `import_course_page.dart` `_autoNavigateLoop` 无 break 状态机 — 极度脆弱 🚫 误报/无需修复（2026-06-18）
**严重性: MEDIUM** | 鲁棒性
> 复核状态：误报。Dart `switch` 不会隐式 fall-through，原报告按 C/Java 语义误判。

- **文件:** `lib/screens/import_course_page.dart:784-833`
- 所有 `case` (CAS_LOGIN → JW_LOGIN → JW_SSO_LOGIN → STUDENT_HOME → TIMETABLE/EXAM → OTHER) 无 break，依次 fall-through
- 可能是有意设计的顺序页面导航，但任一中间步骤失败时，fall-through 继续执行后续 case → 导航状态损坏
- **建议:** 重构为显式状态转换，每步检查结果后显式跳转

### 🟡 中优先级 (Medium)

#### N-29: 硬编码周数上限 30 与设置解耦
**严重性: MEDIUM** | 数据一致性
- **文件:** `lib/providers/timetable_view_provider.dart:16,23,43`
- `week.clamp(1, 30)` 硬编码，但 `SettingsProvider.totalWeeks`（默认18，用户可配置）可能 >30
- 用户设置 totalWeeks >30 后，显示与实际可用周数不匹配
- **建议:** 从 `SettingsProvider` 动态读取，或将 30 定义为含注释的命名常量

#### N-30: `settings_provider.dart` `deleteSemester` 无错误处理
**严重性: MEDIUM** | 鲁棒性
- **文件:** `lib/providers/settings_provider.dart:376-382`
- 调用 `_storageService.deleteSemester()` → `_reloadSemesterState()` → `notifyListeners()` → `await _handleSemesterChange()`
- 全部无 try/catch，与 S-2 同一模式

#### N-31: `TimetableForegroundService` 无 `FOREGROUND_SERVICE_TYPE_DATA_SYNC`
**严重性: MEDIUM** | Android 14+
- **文件:** `AndroidManifest.xml:66-72`
- 声明 `android:foregroundServiceType="specialUse"` 含 justification
- Android 14+ 若系统认为工作不适合 "specialUse"，可能仍杀服务
- **建议:** 评估 `dataSync` 类型是否更适合课表刷新场景

#### N-32: `scheduleVisibilityAlarm` 静默吃掉 `SecurityException`
**严重性: MEDIUM** | Android
- **文件:** `TimetableForegroundService.kt:366-368`
- `setExactAndAllowWhileIdle` 抛 `SecurityException` 时 catch 后降级到 `set()` (inexact)
- 权限问题被静默隐藏，用户不知道闹钟精度下降
- 诊断测试 (`runOneMinuteMuteTest`) 部分缓解

#### N-33: `app_wheel_pickers.dart` 不安全 `as int` 类型转换
**严重性: MEDIUM** | 鲁棒性
- **文件:** `lib/widgets/common/app_wheel_pickers.dart:712-713`
- `String _twoDigits(Object value) { return (value as int).toString()... }` — 参数类型 `Object`，无条件 `as int`
- 泛型 `_ValueWheelSheet<T>` 中调用，`T` 可为任意类型 → 运行时 TypeError
- **建议:** 改为 `String _twoDigits(int value)` 或加类型检查

### 🟢 低优先级 (Low)

#### N-34: `pubspec.yaml` Dart SDK 约束可疑
**严重性: LOW** | 配置
- **文件:** `pubspec.yaml:7`
- `environment: sdk: ^3.11.3` — Dart SDK 无 3.11 版本（当前为 3.4~3.7 范围）
- `^3.11.3` 含义为 `>=3.11.3 <4.0.0`，可能引起 pub 解析异常
- **建议:** 确认正确版本，应为 `^3.4.0` 或 `>=3.2.0 <4.0.0`

#### N-35: `webview_flutter_android` 精确版本固定
**严重性: LOW** | 配置
- **文件:** `pubspec.yaml:17`
- `webview_flutter_android: 4.10.13` — 无 `^` 前缀，阻止自动 patch 更新
- 父包 `webview_flutter: ^4.13.0` 使用 caret，不一致
- **建议:** 使用 `^4.10.13` 或添加注释说明固定原因

#### N-36: `AlarmReceiver` 多个 WakeLock 叠加导致 CPU 满载
**严重性: LOW** | 电池/性能
- **文件:** `AlarmReceiver.kt:32-36`
- 硬编码 10 秒 WakeLock 超时，建议在操作完成 `finally` 中释放而非仅依赖超时
- 多个闹钟同时触发时 WakeLock 叠加

#### N-37: `_buildEmptyStateActions` 每次构建创建新 widget
**严重性: LOW** | 性能
- **文件:** `lib/screens/timetable_page.dart:374-388`
- 在 `PageView.builder` 的 `itemBuilder` 中每次调用创建新的 `_EmptyStateActions` + 闭包
- 滚动时增加 GC 压力
- **建议:** 使用 `const` 构造函数或缓存

#### N-38: Kotlin `Calendar` 非线程安全使用
**严重性: LOW** | Android
- **文件:** `TimetableForegroundService.kt:480-488`
- `Calendar.getInstance()` 在 `startOfLocalDayMillis()` 中使用
- 当前仅主线程调用安全，但从 AlarmManager 回调调用时有线程安全风险

---

## 📊 综合修复优先级路线图（更新）

> 状态说明：本表来自原始第二轮报告，未剔除 2026-06-18 已修复/误报条目；继续修复时请先参考顶部状态更新。

| 阶段 | 目标 | 工作项 |
|---|---|---|
| **Phase 1** (紧急) | 防崩溃/防数据丢失 | S-2 (Provider try/catch), S-3 (mounted检查), S-4 (前台服务), S-5 (!! 解包), **S-6 (key.properties gitignore)**, **N-20 (ChangeNotifier 累积泄漏)**, **N-21 (switch fall-through Bug)** |
| **Phase 2** (安全) | 堵安全漏洞 | S-1 (更新管线签名), H-3 (WebView密码注入), M-1 (URL白名单), **N-19 (WebViewController dispose)** |
| **Phase 3** (架构) | 降低技术债 | H-1 (拆God Class), H-6 (统一hash), H-5 (模型==), N-22 (Provider dispose), N-23 (DJB2 vs FNV), N-12 (增量重载), N-28 (状态机重构) |
| **Phase 4** (完善) | 提升质量 | M-5 (ROM兼容), H-2 (fire-and-forget), N-4 (开机ANR), N-5 (迁移竞态), N-14 (全局错误边界), N-24~N-38, L-1~L-16 |

---

## 📈 最终统计

> 状态说明：以下统计为修复前报告统计，当前工作树已有多项关闭，未在此表重新核算。

| 类别 | 原始报告 | 第二轮验证确认 | 新发现 | 无效/不准确 | 当前有效问题 |
|------|---------|--------------|--------|-------------|-------------|
| 🔴 严重 | 5 | 4 (修正1) | 5 (S-6,N-19,N-20,N-21,N-22) | 0 | **9** |
| 🟠 高优 | 6 | 5 (修正1) | 4 (N-23~N-28) | 0 | **9** |
| 🟡 中等 | 11 | 9 (修正2) | 5 (N-29~N-33) | 0 | **14** |
| 🟢 低优 | 16 | 10 | 5 (N-34~N-38) | 1 (L-7) | **15** |
| 🔵 新增(N) | 18 | 12 (修正3) | — | 3 (N-9,N-17,N-18) | **15** |
| **合计** | **56** | **40** | **19** | **4** | **62** |

核心风险集中在**更新管线安全性**、**Provider层数据持久化可靠性**、**Android 原生代码鲁棒性**和**内存泄漏（WebView + ChangeNotifier）**四个方面。
