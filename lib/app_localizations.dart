class AppStrings {
  static const Map<String, Map<String, String>> dict = {
    'settings': {'zh': '设置', 'en': 'Settings'},
    'appearance': {'zh': '外观', 'en': 'Appearance'},
    'theme_color': {'zh': '主题颜色', 'en': 'Theme Color'},
    'theme_color_subtitle': {
      'zh': '切换课表、按钮和强调信息的主色与辅助色',
      'en': 'Change the primary and accent colors used across the app',
    },
    'theme_teal_orange': {'zh': '青绿 / 橙色', 'en': 'Teal / Orange'},
    'theme_blue_amber': {'zh': '蓝色 / 琥珀', 'en': 'Blue / Amber'},
    'theme_violet_pink': {'zh': '紫色 / 粉色', 'en': 'Violet / Pink'},
    'theme_green_lime': {'zh': '绿色 / 青柠', 'en': 'Green / Lime'},
    'theme_custom': {'zh': '自定义颜色', 'en': 'Custom Colors'},
    'theme_custom_subtitle': {
      'zh': '从调色盘选择主色和辅助色，点选后立即应用',
      'en':
          'Choose primary and accent colors from the palette. Changes apply instantly.',
    },
    'primary_color': {'zh': '主色', 'en': 'Primary Color'},
    'accent_color': {'zh': '辅助色', 'en': 'Accent Color'},
    'basic_settings': {'zh': '基础设置', 'en': 'Basic Settings'},
    'notifications': {'zh': '提醒设置', 'en': 'Notifications'},
    'app_update': {'zh': '应用更新', 'en': 'App Update'},
    'data_storage': {'zh': '数据管理', 'en': 'Data Management'},
    'account_settings': {'zh': '账号', 'en': 'Account'},
    'academic_account_title': {'zh': '教务账号', 'en': 'Academic Account'},
    'academic_account_subtitle': {
      'zh': '保存账密，并自动提取课程或考试信息',
      'en': 'Save credentials and auto import timetable or exams',
    },
    'check_update': {'zh': '检查更新', 'en': 'Check for Updates'},
    'check_update_subtitle': {
      'zh': '手动检测新版本',
      'en': 'Manually check for a new version',
    },
    'checking_update': {'zh': '正在检测更新...', 'en': 'Checking for updates...'},
    'already_latest': {
      'zh': '当前已是最新版本',
      'en': 'You are already on the latest version.',
    },
    'update_check_failed': {
      'zh': '更新检查失败，请稍后重试',
      'en': 'Update check failed. Please try again later.',
    },
    'update_not_supported': {
      'zh': '当前平台不支持应用内更新',
      'en': 'In-app updates are not supported on this platform.',
    },
    'update_unsupported_abi': {
      'zh': '发现新版本，但当前设备架构暂无可用安装包',
      'en':
          'A new version is available, but no APK matches this device architecture.',
    },
    'update_download_failed': {
      'zh': '更新下载失败，请稍后重试',
      'en': 'Update download failed. Please try again later.',
    },
    'update_backup_failed': {
      'zh': '本地数据备份失败，已取消更新',
      'en': 'Local data backup failed. Update canceled.',
    },
    'update_install_opened': {
      'zh': '已打开系统安装器，请确认安装',
      'en': 'System installer opened. Please confirm installation.',
    },
    'update_install_permission_opened': {
      'zh': '请允许安装未知应用，返回后将自动继续安装',
      'en':
          'Allow installing unknown apps. Installation will resume when you return.',
    },
    'update_install_failed': {
      'zh': '无法打开安装器，请允许安装未知应用后重试',
      'en':
          'Unable to open the installer. Allow installing unknown apps and try again.',
    },
    'update_now': {'zh': '立即更新', 'en': 'Update Now'},
    'new_version_title': {
      'zh': '发现新版本 {version}',
      'en': 'New version {version} available',
    },
    'language': {'zh': '语言 / Language', 'en': 'Language / 语言'},
    'semester_start_date': {'zh': '第一周开始日期', 'en': 'First Week Start Date'},
    'semester_total_weeks': {'zh': '学期总周数', 'en': 'Total Semester Weeks'},
    'schedule_time_settings': {
      'zh': '作息时间与节次设置',
      'en': 'Class Time & Period Settings',
    },
    'schedule_time_settings_subtitle': {
      'zh': '编辑每天的上课节次和时间段',
      'en': 'Edit daily class periods and time ranges',
    },
    'course_reminder_time': {'zh': '课程提前提醒', 'en': 'Course Reminder'},
    'event_reminder_time': {'zh': '日程提前提醒', 'en': 'Event Reminder'},
    'reminder_time': {'zh': '课前提醒时间', 'en': 'Reminder Advance Time'},
    'no_reminder': {'zh': '不提醒', 'en': 'None'},
    'one_hour': {'zh': '提前 1 小时', 'en': 'Before 1 hour'},
    'two_hours': {'zh': '提前 2 小时', 'en': 'Before 2 hours'},
    'one_day': {'zh': '提前 1 天', 'en': 'Before 1 day'},
    'auto_mute': {
      'zh': '上课自动静音（仅 Android）',
      'en': 'Auto Mute During Class (Android only)',
    },
    'auto_mute_subtitle': {
      'zh': '上课自动切为震动，下课恢复正常铃声',
      'en':
          'Switch to vibrate during class and restore normal mode after class',
    },
    'auto_mute_permission_required': {
      'zh': '需要勿扰模式权限，请在系统设置中授权后再开启',
      'en':
          'Do Not Disturb access is required. Grant it in system settings first.',
    },
    'auto_mute_not_supported': {
      'zh': '该功能目前仅支持 Android',
      'en': 'This feature is currently available on Android only.',
    },
    'clear_browser_cache': {'zh': '清除浏览器缓存', 'en': 'Clear Browser Cache'},
    'clear_browser_cache_subtitle': {
      'zh': '解决教务系统登录失效',
      'en': 'Fix expired academic system login',
    },
    'clear_all_local_data': {'zh': '清除所有本地数据', 'en': 'Clear All Local Data'},
    'clear_all_local_data_subtitle': {
      'zh': '清空课程和日程，操作不可恢复',
      'en': 'Delete all courses and events permanently',
    },
    'weeks_suffix': {'zh': '周', 'en': 'weeks'},
    'minutes_suffix': {'zh': '分钟', 'en': 'min'},
    'cache_cleared': {
      'zh': '缓存已清除，下次导入需重新登录',
      'en': 'Cache cleared. Login again next time you import.',
    },
    'confirm_clear': {'zh': '确认清空', 'en': 'Confirm Clear'},
    'confirm_clear_message': {
      'zh': '确定要清空所有本地课程和日程数据吗？此操作不可逆。',
      'en': 'Clear all local courses and events? This action cannot be undone.',
    },
    'cancel': {'zh': '取消', 'en': 'Cancel'},
    'confirm': {'zh': '确认', 'en': 'Confirm'},
    'all_local_data_cleared': {
      'zh': '本地课程与日程数据已清空',
      'en': 'Local courses and events have been cleared.',
    },
    'chinese': {'zh': '中文', 'en': 'Chinese'},
    'english': {'zh': 'English', 'en': 'English'},
    'advance_prefix': {'zh': '提前', 'en': 'Before'},
    'timetable': {'zh': '课表', 'en': 'Timetable'},
    'day_view': {'zh': '日视图', 'en': 'Day View'},
    'week_view': {'zh': '周视图', 'en': 'Week View'},
    'import_from_system': {'zh': '导入教务课表', 'en': 'Import from Academic System'},
    'today': {'zh': '回到今日', 'en': 'Today'},
    'add_course': {'zh': '添加课程/日程', 'en': 'Add Course/Event'},
    'jump_to_week': {'zh': '跳转周次', 'en': 'Jump to Week'},
    'week_label_format': {'zh': '第 {week} 周', 'en': 'Week {week}'},
    'period_range_format': {
      'zh': '第 {start}-{end} 节',
      'en': 'Period {start}-{end}',
    },
    'no_courses_today': {'zh': '今天没有课程。', 'en': 'No courses today.'},
    'no_courses_for_day': {
      'zh': '本周这一天没有课程或日程。',
      'en': 'No courses or events for this day in this week.',
    },
    'teacher': {'zh': '教师', 'en': 'Teacher'},
    'location': {'zh': '地点', 'en': 'Location'},
    'note': {'zh': '备注', 'en': 'Note'},
    'periods': {'zh': '节次', 'en': 'Periods'},
    'time': {'zh': '时间', 'en': 'Time'},
    'weekday': {'zh': '星期', 'en': 'Weekday'},
    'weeks': {'zh': '周次', 'en': 'Weeks'},
    'edit_course': {'zh': '编辑课程', 'en': 'Edit Course'},
    'delete_course': {'zh': '删除课程', 'en': 'Delete Course'},
    'confirm_delete_course_title': {
      'zh': '删除这门课程？',
      'en': 'Delete this course?',
    },
    'confirm_delete_course_message': {
      'zh': '该课程会从当前学期中移除，操作不可恢复。',
      'en': 'This course will be removed from the current semester.',
    },
    'alarm': {'zh': '提醒', 'en': 'Alarm'},
    'enabled': {'zh': '开启', 'en': 'Enabled'},
    'disabled': {'zh': '关闭', 'en': 'Disabled'},
    'delete_event': {'zh': '删除日程', 'en': 'Delete Event'},
    'confirm_delete_event_title': {'zh': '删除这个日程？', 'en': 'Delete this event?'},
    'confirm_delete_event_message': {
      'zh': '该日程会被永久删除，操作不可恢复。',
      'en': 'This event will be permanently deleted.',
    },
    'location_pending': {'zh': '地点待定', 'en': 'Location pending'},
    'not_set': {'zh': '未设置', 'en': 'Not set'},
    'add_schedule': {'zh': '添加日程', 'en': 'Add Schedule'},
    'add_event': {'zh': '添加日程', 'en': 'Add Event'},
    'save': {'zh': '保存', 'en': 'Save'},
    'saving': {'zh': '保存中...', 'en': 'Saving...'},
    'save_changes': {'zh': '保存修改', 'en': 'Save Changes'},
    'course_name': {'zh': '课程名称', 'en': 'Course Name'},
    'event_name': {'zh': '日程名称', 'en': 'Event Name'},
    'weekday_label': {'zh': '星期几', 'en': 'Weekday'},
    'teaching_weeks': {'zh': '上课周次', 'en': 'Teaching Weeks'},
    'select_all': {'zh': '全选', 'en': 'Select All'},
    'clear_selection': {'zh': '清空', 'en': 'Clear'},
    'odd_weeks': {'zh': '单周', 'en': 'Odd Weeks'},
    'even_weeks': {'zh': '双周', 'en': 'Even Weeks'},
    'start_period': {'zh': '开始节次', 'en': 'Start Period'},
    'end_period': {'zh': '结束节次', 'en': 'End Period'},
    'card_color': {'zh': '卡片颜色', 'en': 'Card Color'},
    'date_time': {'zh': '日期与时间', 'en': 'Date & Time'},
    'date': {'zh': '日期', 'en': 'Date'},
    'select_event_time': {'zh': '请选择日程时间', 'en': 'Select the event time'},
    'select_date': {'zh': '请选择日期', 'en': 'Select date'},
    'select_time': {'zh': '请选择时间', 'en': 'Select time'},
    'enable_alarm_reminder': {'zh': '开启提醒', 'en': 'Enable Alarm Reminder'},
    'course_updated': {'zh': '课程已更新', 'en': 'Course updated'},
    'course_added': {'zh': '课程已添加', 'en': 'Course added'},
    'event_added': {'zh': '日程已添加', 'en': 'Event added'},
    'please_enter_course_name': {
      'zh': '请输入课程名称',
      'en': 'Please enter a course name',
    },
    'please_enter_location': {'zh': '请输入地点', 'en': 'Please enter a location'},
    'please_enter_event_name': {
      'zh': '请输入日程名称',
      'en': 'Please enter an event name',
    },
    'please_select_weekday': {
      'zh': '请至少选择一个星期几',
      'en': 'Please select at least one weekday',
    },
    'please_select_teaching_week': {
      'zh': '请至少选择一个上课周次',
      'en': 'Please select at least one teaching week',
    },
    'configure_periods_first': {
      'zh': '请先在设置中配置上课节次',
      'en': 'Please configure class periods in Settings first',
    },
    'selected_periods_out_of_range': {
      'zh': '所选节次超出范围',
      'en': 'Selected periods are out of range',
    },
    'end_period_invalid': {
      'zh': '结束节次必须大于或等于开始节次',
      'en': 'End period must be greater than or equal to start period',
    },
    'please_select_date_time': {
      'zh': '请选择日期和时间',
      'en': 'Please select a date and time',
    },
    'timeline_density': {'zh': '时间轴密度', 'en': 'Timeline Density'},
    'class_duration': {'zh': '单节时长', 'en': 'Class Duration'},
    'short_break': {'zh': '小课间', 'en': 'Short Break'},
    'big_break': {'zh': '大课间', 'en': 'Big Break'},
    'morning': {'zh': '上午', 'en': 'Morning'},
    'afternoon': {'zh': '下午', 'en': 'Afternoon'},
    'evening': {'zh': '晚上', 'en': 'Evening'},
    'session_start': {'zh': '开始时间', 'en': 'Start Time'},
    'session_classes': {'zh': '节次数量', 'en': 'Class Count'},
    'period_count': {'zh': '节', 'en': 'period(s)'},
    'monday': {'zh': '周一', 'en': 'Monday'},
    'tuesday': {'zh': '周二', 'en': 'Tuesday'},
    'wednesday': {'zh': '周三', 'en': 'Wednesday'},
    'thursday': {'zh': '周四', 'en': 'Thursday'},
    'friday': {'zh': '周五', 'en': 'Friday'},
    'saturday': {'zh': '周六', 'en': 'Saturday'},
    'sunday': {'zh': '周日', 'en': 'Sunday'},
    'mon_short': {'zh': '周一', 'en': 'Mon'},
    'tue_short': {'zh': '周二', 'en': 'Tue'},
    'wed_short': {'zh': '周三', 'en': 'Wed'},
    'thu_short': {'zh': '周四', 'en': 'Thu'},
    'fri_short': {'zh': '周五', 'en': 'Fri'},
    'sat_short': {'zh': '周六', 'en': 'Sat'},
    'sun_short': {'zh': '周日', 'en': 'Sun'},
    'event_marker': {'zh': '日程', 'en': 'Event'},
    'academic_import': {'zh': '教务信息导入', 'en': 'Academic Info Import'},
    'academic_account_section': {'zh': '账号密码', 'en': 'Credentials'},
    'academic_student_id': {'zh': '学号', 'en': 'Student ID'},
    'academic_password': {'zh': '密码', 'en': 'Password'},
    'academic_auto_login_enabled': {
      'zh': '保存后启用自动登录',
      'en': 'Enable auto login',
    },
    'academic_credentials_notice': {
      'zh': '账号密码仅加密保存在本机，用于自动登录教务系统；启用后应用每天首次打开或回到前台会静默补拉课表。',
      'en':
          'Credentials are encrypted on this device and only used for academic login. When enabled, the app silently refreshes the timetable once per day on launch or resume.',
    },
    'save_academic_credentials': {'zh': '保存账密', 'en': 'Save'},
    'clear_academic_credentials': {'zh': '清除账密', 'en': 'Clear'},
    'academic_import_actions': {'zh': '教务提取', 'en': 'Academic Import'},
    'auto_extract_timetable': {'zh': '自动提取课程', 'en': 'Auto Import Timetable'},
    'auto_extract_timetable_subtitle': {
      'zh': '后台打开教务课表页，经统一门户自动登录后导入课程',
      'en':
          'Open the timetable page in the background, sign in through the unified portal, and import courses',
    },
    'auto_extract_exam': {'zh': '自动提取考试', 'en': 'Auto Import Exams'},
    'auto_extract_exam_subtitle': {
      'zh': '考试页会等待更久，并尝试点击考试信息查询旁的刷新按钮',
      'en': 'Wait longer on the exam page and try the refresh button',
    },
    'manual_academic_import': {
      'zh': '手动打开教务页面',
      'en': 'Open Academic Page Manually',
    },
    'manual_academic_import_subtitle': {
      'zh': '保留浏览器页面，手动登录或导航后点击一键提取',
      'en': 'Keep the browser visible for manual login and extraction',
    },
    'auto_login_extract': {'zh': '自动登录并提取', 'en': 'Auto Login & Extract'},
    'auto_login_extract_exam': {
      'zh': '自动登录并提取考试',
      'en': 'Auto Login & Extract Exams',
    },
    'academic_credentials_empty': {
      'zh': '请先填写学号和密码。',
      'en': 'Please enter your student ID and password first.',
    },
    'academic_credentials_saved': {
      'zh': '账号密码已安全保存。',
      'en': 'Credentials saved securely.',
    },
    'academic_credentials_cleared': {
      'zh': '已清除保存的账号密码。',
      'en': 'Saved credentials cleared.',
    },
    'auto_import_opening': {
      'zh': '正在打开教务课表页面...',
      'en': 'Opening academic timetable...',
    },
    'auto_import_preparing': {
      'zh': '正在准备自动提取...',
      'en': 'Preparing auto import...',
    },
    'auto_import_hidden_webview_notice': {
      'zh': '自动流程会先进入统一登录门户，再使用保存的账密登录；失败后可手动打开教务页面。',
      'en':
          'The flow enters the unified portal and signs in with saved credentials. Use manual import if it fails.',
    },
    'auto_import_logging_in': {
      'zh': '已提交登录，正在等待跳转...',
      'en': 'Login submitted. Waiting for redirect...',
    },
    'auto_import_redirecting_portal': {
      'zh': '正在跳转统一登录门户...',
      'en': 'Redirecting to the unified login portal...',
    },
    'auto_import_waiting_unified_login': {
      'zh': '正在等待统一登录门户表单加载...',
      'en': 'Waiting for the unified portal login form...',
    },
    'auto_import_submit_missing': {
      'zh': '统一登录门户未找到登录按钮，请手动打开教务页面登录后重试。',
      'en':
          'The unified portal login button was not found. Open the academic page manually, sign in, and try again.',
    },
    'auto_import_waiting_table': {
      'zh': '正在等待课表加载...',
      'en': 'Waiting for timetable...',
    },
    'auto_import_waiting_page': {
      'zh': '正在等待教务页面响应...',
      'en': 'Waiting for academic page...',
    },
    'auto_import_extracting': {
      'zh': '已进入课表，正在提取...',
      'en': 'Timetable ready. Extracting...',
    },
    'auto_exam_import_opening': {
      'zh': '正在打开考试安排页面...',
      'en': 'Opening exam schedule...',
    },
    'auto_exam_import_waiting_table': {
      'zh': '正在刷新并等待考试信息加载...',
      'en': 'Refreshing and waiting for exam information...',
    },
    'auto_exam_import_extracting': {
      'zh': '已进入考试页面，正在提取...',
      'en': 'Exam page ready. Extracting...',
    },
    'auto_import_failed': {
      'zh': '教务导入失败：{reason}。你可以继续手动操作后点击一键提取课表。',
      'en':
          'Academic import failed: {reason}. You can continue manually and tap Extract Timetable.',
    },
    'auto_import_timeout': {
      'zh': '等待统一门户登录或教务页面加载超时',
      'en': 'Timed out waiting for unified login or academic page loading',
    },
    'auto_import_challenge_required': {
      'zh': '检测到验证码或二次验证，需要手动完成',
      'en':
          'Captcha or second verification detected; manual action is required',
    },
    'extract_timetable': {'zh': '一键提取课表', 'en': 'Extract Timetable'},
    'extracting': {'zh': '正在提取...', 'en': 'Extracting...'},
    'extract_exam': {'zh': '一键提取考试', 'en': 'Extract Exams'},
    'extracting_exam': {'zh': '正在提取考试...', 'en': 'Extracting exams...'},
    'exam_extract_pending': {
      'zh': '考试信息解析功能框架已就绪，具体解析逻辑待实现',
      'en':
          'The exam extraction framework is ready. Parsing logic is not implemented yet.',
    },
    'exam_import_empty': {
      'zh': '当前页面没有未结束考试安排',
      'en': 'No unfinished exams were found on this page.',
    },
    'exam_import_duplicated': {
      'zh': '考试信息已存在，未重复导入',
      'en': 'Exam information already exists. Nothing was imported.',
    },
    'exam_import_success_format': {
      'zh': '已导入 {count} 条考试信息',
      'en': 'Imported {count} exam item(s)',
    },
    'timetable_import_success_format': {
      'zh': '已导入 {count} 门课程',
      'en': 'Imported {count} course(s)',
    },
    'timetable_import_skipped_format': {
      'zh': '{summary}，跳过 {count} 条：{reasons}',
      'en': '{summary}; skipped {count}: {reasons}',
    },
    'guide_next': {'zh': '下一步', 'en': 'Next'},
    'guide_done': {'zh': '我知道了', 'en': 'Got it'},
    'guide_step_counter': {
      'zh': '第 {current}/{total} 步',
      'en': 'Step {current}/{total}',
    },
    'guide_timetable_week_title': {'zh': '切换周次', 'en': 'Switch Weeks'},
    'guide_timetable_week_body': {
      'zh': '点这里可以跳转到指定教学周，快速查看不同周的课程安排。',
      'en': 'Jump to a teaching week and review that week quickly.',
    },
    'guide_timetable_today_title': {'zh': '回到今天', 'en': 'Back to Today'},
    'guide_timetable_today_body': {
      'zh': '无论滑到了哪一天，点这里都会回到今天所在的位置。',
      'en': 'Return to today no matter where you have scrolled.',
    },
    'guide_timetable_overview_title': {'zh': '课程总览', 'en': 'Course Overview'},
    'guide_timetable_overview_body': {
      'zh': '查看当前学期的全部课程列表，适合快速查找课程。',
      'en': 'View all courses in the current semester for quick lookup.',
    },
    'guide_timetable_import_title': {'zh': '导入课表', 'en': 'Import Timetable'},
    'guide_timetable_import_body': {
      'zh': '从教务系统打开导入页面，登录后可以一键解析课程信息和考试信息。',
      'en':
          'Open the academic import page and extract courses and exam after login.',
    },
    'guide_timetable_add_title': {'zh': '手动添加', 'en': 'Add Manually'},
    'guide_timetable_add_body': {
      'zh': '需要补充课程或日程时，可以从这里手动新增。',
      'en': 'Add a course or schedule manually when you need to fill gaps.',
    },
    'guide_import_webview_title': {'zh': '教务系统页面', 'en': 'Academic WebView'},
    'guide_import_webview_body': {
      'zh': '这里会打开教务系统。可保存账密后自动登录提取，也可手动进入课表或考试页面后再提取。',
      'en':
          'The academic system opens here. You can save credentials for auto import or navigate manually before extraction.',
    },
    'guide_import_exam_title': {'zh': '解析考试', 'en': 'Extract Exams'},
    'guide_import_exam_body': {
      'zh': '进入考试安排页面后点这里，应用会读取页面内容并导入考试信息。',
      'en': 'Tap this after opening the exam schedule page and import exam.',
    },
    'guide_import_timetable_title': {'zh': '解析课表', 'en': 'Extract Timetable'},
    'guide_import_timetable_body': {
      'zh': '进入课表页面后点这里，应用会读取页面内容并导入课程。',
      'en':
          'Tap this after opening the timetable page to read and import courses.',
    },
    'import_success': {'zh': '成功导入课程', 'en': 'Successfully imported courses'},
    'reschedule_course': {'zh': '\u8c03\u8bfe', 'en': 'Reschedule Course'},
    'reschedule_success': {
      'zh': '\u8c03\u8bfe\u6210\u529f',
      'en': 'Course rescheduled',
    },
    'reschedule_unavailable': {
      'zh': '\u65e0\u6cd5\u8c03\u8bfe\uff0c\u8bf7\u91cd\u8bd5',
      'en': 'Unable to reschedule course',
    },
    'target_week': {'zh': '\u76ee\u6807\u5468\u6b21', 'en': 'Target Week'},
    'target_weekday': {
      'zh': '\u76ee\u6807\u661f\u671f',
      'en': 'Target Weekday',
    },
    'target_start_period': {
      'zh': '\u76ee\u6807\u5f00\u59cb\u8282\u6b21',
      'en': 'Target Start Period',
    },
    'target_end_period': {
      'zh': '\u76ee\u6807\u7ed3\u675f\u8282\u6b21',
      'en': 'Target End Period',
    },
    'original_schedule': {
      'zh': '\u539f\u8bfe\u7a0b\u5b89\u6392',
      'en': 'Original Schedule',
    },
    'invalid_reschedule_period_range': {
      'zh':
          '\u5f53\u524d\u8bfe\u7a0b\u8282\u6b21\u8d85\u51fa\u53ef\u914d\u7f6e\u8303\u56f4',
      'en': 'This course period range is out of the configured limit',
    },
    'duplicate_course_not_added': {
      'zh':
          '\u76f8\u540c\u8bfe\u7a0b\u5df2\u5b58\u5728\uff0c\u672a\u91cd\u590d\u6dfb\u52a0',
      'en': 'An identical course already exists and was not added',
    },
  };

  static String get(String key, String languageCode) {
    return dict[key]?[languageCode] ?? dict[key]?['zh'] ?? key;
  }
}
