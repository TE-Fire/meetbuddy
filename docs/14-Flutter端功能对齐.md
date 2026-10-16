# 14 · Flutter 端功能对齐

## 背景与目标

到 2026-10-15，小程序侧已经有 16 个页面，M7/M8 之后的增量（勋章、通知中心、分享海报、我的日程、他人主页、关注关系、活动编辑、兴趣标签、头像、列表排序、信用明细、找搭子）全部落在**小程序侧**；Flutter 端停在 M5 的 8 个页面（登录 / 发现 / 详情 / 发布 / 聊天室 / 消息 / 我的 / HomeShell）。TE 拍板把缺口补到 Flutter 端，为装机调试做准备。

这件事的性质要先说清：**它是纯 Flutter 侧的工作**。后端接口全部就绪且都已联调过（`docs/03` 的接口契约没变），所以这里只加 Dart 代码，不动 `server/`。

## 为什么不能"把小程序代码搬过来"

WXML/WXSS 与 Dart widget 是两套渲染体系，**零复用**。能沿用的只有两样东西：后端接口契约，以及 M5 已经跑通的 repository 分层。所以每个页面都是"照小程序那边的结论重画 UI"，而不是复制粘贴——工作量按页面算，不按文件数算。

分层沿用 M5（详见 `mobile/README.md`）：

| 层 | 职责 |
| --- | --- |
| `model/` | 纯数据类，`fromJson` 统一用 `json_util` 的取值函数 |
| `repository/` | 抽象接口；`real/` 走 HTTP、`mock/` 走内存，两套并存 |
| `state/` | `ChangeNotifier`，经 provider 注入 |
| `page/` `widget/` | UI |

一个硬约束：`app_scope.dart` 是全项目唯一读 `Env.useMock` 的地方（`docs/01` 第八节）。**新增数据源必须在这一处同时注册 real 与 mock 两个实现**，页面与 state 只认抽象接口。

## 批次计划

| 批次 | 内容 | 状态 |
| --- | --- | --- |
| 1 | profile 增强（标签 / 关注粉丝计数 / 资料编辑）、feed 排序、detail 头像接真图 | 已完成 |
| 2 | user-profile（他人主页）、follow-list（关注/粉丝）、notification（通知中心） | 已完成 |
| 2.5 | 交互手感返工：按压反馈铺满、骨架改扫光、入场时长收紧 | 已完成 |
| 2.5 续 | 按钮点击反馈、tab 切换动画、验证码三态与图标、封面日期徽标补画 | 已完成 |
| 2.5 再续 | 表单与按钮质感：`AppField` 四态、按钮渐变与受光边、光标选区统一 | 已完成 |
| 3 | activity-edit（活动编辑改期）、badge（勋章）、schedule（日程）、credit-log（信用明细） | 已完成 |
| 4 | poster（分享海报）、buddy（找搭子） | 已完成 |

第 2.5 批不是原计划里的批次，是第 2 批做完后 TE 在预览里上手反馈「交互太僵硬了，没有呼吸感」而插进来的返工。动效口径已定稿到 `docs/01` 第九节。后续 TE 又连续追加三轮（按钮反馈与 tab 动画、验证码图标、封面日期标签、表单与按钮质感），都归在这条线下，不另起批次号——它们都是同一件事的延伸：让界面"活起来"。

批次表里的"detail 头像接真图"是执行中从原计划的"detail 编辑入口"换过来的：编辑入口必须先有落地页，而编辑页属第 3 批（理由见"未做项"）。详情页真正缺的是头像——小程序那边组织者卡与报名人药丸都接了真图，Flutter 还停在首字母色块，同一场活动在两端会显示成两个人。

## 第 1 批交付

### 「我的」页

- **兴趣标签**：展示为软标签；编辑面板含 26 个预设池、自定义输入（≤10 字、去重、封顶 20 个）、已选项可单个删除。保存走 `PUT /api/user/tags`。
- **关注 / 粉丝计数**：数据条从「信用分 / 我发起的 / 我报名的」改成「关注 / 粉丝 / 我发起的 / 我报名的」。前两项取自 `GET /api/user/{id}/profile`，后两项点了切 Tab。
- **资料编辑面板**：昵称 / 简介 / 性别，走 `PUT /api/user/profile`。保存后同时刷新 `SharedPreferences` 缓存，避免下次冷启动先闪出旧昵称。
- **头像接真图**：`Image.network` + `Env.imgUrl()` 拼前缀；无图或加载失败都回落首字母渐变底，不会在页面正中留一个破图。

计数取数**刻意没有新增后端接口**，也没有把计数塞进 `UserVO`——那会让报名列表、聊天等所有 `UserVO.from` 的构造点都得跟着填值。改为在 profile 页并一次 `/user/{id}/profile`，失败时静默保留上一次的值，不把已有数字打回 0。

### 活动流排序

在分类 chips 下加一行「最新 / 最热 / 最近」，对应后端 `sortBy=latest|hot|distance`，与分类、关键字、就近筛选**全部可叠加**。`distance` 依赖经纬度，未开就近时该项置灰而不是隐藏——隐藏会让这一行在两个状态间来回改长度，置灰还能顺带提示"有这个能力"。

### 活动详情的头像

组织者卡（42）与报名人药丸（26）从"渐变底首字母"换成真图。顺带把头像逻辑抽成 `widget/ui.dart` 的 `UserAvatar`：原先 `profile_page.dart` 里有一份私有的 `_avatarBox`，详情页再抄一遍就会变成第三份，而 `errorBuilder` 少写一个展示点，真机上就是页面正中一个破图。

归一化（相对路径拼 `apiBase`、绝对地址原样返回）收进组件内部，调用方把后端返回的 `avatar` 原样传进去。这一条是刻意的：**"判断是不是 `http` 开头"的逻辑散在页面里，迟早会有一处漏掉**，而漏掉的那处只在特定账号（设过头像）身上才现形。

活动流卡片上的头像**没有**跟着改，因为它两端都是首字叠加（小程序 feed 卡片本来就不渲染真图），改了反而不一致。

## 第 2 批交付

三个新页面，外加为它们补的支撑层。支撑层不是"顺手写的"——三个页面分别依赖关注关系、通知未读、以及"用户 id → 昵称头像"的解析，这些在 M5 里都不存在。

### 支撑层

| 新增 | 内容 |
| --- | --- |
| `model/badge.dart` | 对应 `BadgeVO`（code / name / desc / icon / group / unlocked / progress / target） |
| `model/user_brief.dart` | 对应 `UserBriefVO`（userId / nickname / avatar / creditScore / banned） |
| `model/recent_activity.dart` | 对应 `UserProfileVO.RecentActivity`，**窄接口**，不复用 `Activity` |
| `model/app_notification.dart` | 对应 `NotificationVO` |
| `repository/notification_repository.dart` + `real/` + `mock/` | `list` / `unread` / `markRead` / `readAll` 四方法 |
| `state/notification_state.dart` | 未读计数、分页、已读，并订阅 WS 的 `notify` 帧 |

`RecentActivity` 刻意不复用 `Activity`：它只有 6 个字段，复用要为一个列表硬填 `Activity` 的十几个必填字段，多出来的字段迟早有人误用。窄接口的代价是 `fromJson` 多写一份，收益是类型上说不出谎。

### 他人主页 `user-profile`

头部是头像 62 + 昵称 + 信用分 / "这是你" / "已封禁" 三个状态标记 + 关注按钮；下面是关注 / 粉丝两个**可点**的计数（接 `follow-list`）、简介、兴趣标签、完成组局 / 完成参与 / 勋章三个计数格、勋章墙、最近完成。

关注走**乐观更新 + 失败回滚**：点击立刻翻状态和计数，请求失败再退回去并弹提示。这里是回滚而不是不回滚，因为关注是**服务端事实**——不回滚会让用户以为关注成功了，下次进来又变回去，比慢半秒更糟。

登录用户看自己的主页时，`_FollowButton` 换成"这是你"，不渲染关注按钮。判断放在页面而不是按钮内部，避免按钮拿到 `userId == me.id` 时还要自己读 session。

### 关注 / 粉丝列表 `follow-list`

`FollowTab` 枚举分两个 tab，两个 body 各自持有分页游标与滚动位置（`AutomaticKeepAliveClientMixin`），切 tab 不重置另一边的进度。空态区分两种："还没关注任何人" vs "还没有人关注"。分页到底判定用**本页返回条数 < size**，不用 `total`——翻页途中新关注会让 `total` 变大，用 `total` 判定会多请求一次空页。

### 通知中心 `notification`

`NotificationTarget` 把"`bizId` 的语义随 `type` 变"这一条收在一处：`SIGNUP_NEW` / `ACTIVITY_*` 指向活动，`USER_FOLLOWED` 指向用户，其余不可跳。页面只问 `notification.target`，不自己 switch `type`——这个 switch 散到页面里，新增通知类型时必然会漏掉一处，表现为"点了没反应"。

未读用**左侧蓝条 + 右上圆点**双重标识（不只用圆点）。小程序那边用 emoji 作图标，Flutter 侧改用 Material 图标——emoji 在不同系统上字体不同，Android 与 Web 渲染出来的视觉重量差很多，这是刻意的不一致。

`_open` 是**先标已读再跳转**，且已读失败不阻断跳转。已读是本地事实，用户点开了就是点开了；为了等一个请求而卡住跳转，或者标失败就不让跳，都是把服务端的一致性强加给用户。

`markRead` 失败**不回滚**，与关注的处理相反。回滚会让红点在用户眼皮底下重新冒出来——"我已经看过了，它又亮了"是比"未读数多算一个"更严重的错觉。

### 红点口径与角标

底部「消息」tab 的红点 = 聊天未读 + 通知未读，与小程序 `custom-tab-bar` 一致。消息页右上角加铃铛进通知中心，铃铛自带同一个未读数。

`bucketBadge`（`n > 99 ? '99+' : '$n'`）从 `home_shell.dart` 迁到 `widget/ui.dart`。它有**三个**消费点——底部导航、消息页铃铛、通知列表——截断规则写三份，改一处就会漏两处。

### WebSocket 的 `notify` 帧

后端 `NotificationServiceImpl` 在接收方在线时推 `{"type":"notify","notification":{...}}`。`ChatEvent` 加了这一帧，`NotificationState.attach()` 订阅同一个 `socket.events` 广播流并去重插入。

`ChatState` 与 `NotificationState` **各订阅各的，不合成"总事件总线"**。合成总线要引入一层分发与生命周期管理，而收益只是省一次订阅；两个 state 各自持有域内状态，边界反而更清楚。

## 第 2.5 批：交互手感返工

TE 反馈「交互太僵硬了，没有呼吸感」。处置前先给了判断：**僵硬不是动画太少，加时长只会更钝**。按三条证据改：

1. **按压反馈覆盖不全**——筛选 chip、统计格子这两类高频点击目标完全没有视觉反馈。`PressableScale` 重写（`scale`/`blur` 参数、快压慢回 110/220ms、叠 0.94 压暗），新增 `BouncyTap` 给"状态翻转"型图标。
2. **骨架屏是静态灰块**——`SkeletonBox` 从明暗呼吸改为扫光（高光带 -1 → 2，1250ms），`SkeletonList` 每块挂载时 260ms 淡入。
3. **入场动画过慢**——`StaggeredIn` 从 55ms × 上限 10 项收到 38ms × 上限 6 项，上浮 14 → 10。

完整口径见 `docs/01` 第九节。覆盖到的文件：`widget/ui.dart`、`widget/category_visual.dart`、`page/activity_feed_page.dart`、`page/profile_page.dart`、`page/user_profile_page.dart`、`page/activity_detail_page.dart`。

### 第 2.5 批（续）：按钮、tab 与封面日期标签

TE 追加三条：按钮之间的点击动画、tab 切换动画、`获取验证码` 之类的 icon、背景图上的日期标签格式。

- **主/次按钮共用一套按压反馈**：`PrimaryButton` 与 `GhostButton` 改走同一个 `_BouncyButtonBody`（缩放 0.965 + 底/框 90ms 压下 200ms 回弹 + 按下收投影）。原先两颗都**完全没有按下反馈**。不套 `PressableScale` 是因为胶囊近满屏宽，整块缩放会像橡皮筋。
- **底部导航加滑块**：选中指示从"两颗各自变色"改成"一个白胶囊滑过去"（`AnimatedAlign` + `FractionallySizedBox(1/3)` + `easeOutBack`）。滑块放底层并 `IgnorePointer`，否则它吃掉点击。
- **TabBar 指示器换胶囊**：`indicator: _PillIndicator()`（自绘 `Decoration`，按"高度一半"算半径避免压窄时退化）+ `TabIndicatorAnimation.elastic`。下划线在浅蓝渐变底上 3px 几乎看不见，用户会以为没选中。
- **TabBarView 关横滑**：两个含长列表的 tab 都设 `NeverScrollableScrollPhysics`——横滑跟列表纵滑抢事件，斜着滑一下列表就翻页。内容过渡由新增 `_TabFade` 补上（挂 `TabController.animation`，淡入 + 6px 上浮）。
- **「获取验证码」补 icon 与三态**：可点（纸飞机）/ 发送中（转圈）/ 倒计时（沙漏 + 进度环 + 浅蓝底蓝字）。**倒计时不是禁用态**，画成灰按钮会被读成"功能坏了"。宽度固定 116，否则倒计时每秒把左边输入框推一下。
- **修封面日期标签**：`ActivityCover` 有 `coverUrl` 时走纯 `Image.network`，`badge` 被整个丢掉——用自己封面的活动反而没有时间信息。两条分支都补画，真图分支再压一层底部渐变遮罩让胶囊边界清晰。配色判定从 `timeText.startsWith('今天')` 改为独立的 `_isToday()`（字符串耦合会在改文案时静默失效）。

自造并在自查中修掉的两处：`_PillPainter.paint` 初版漏了 `offset`（所有胶囊会画到左上角）；`GhostButton` 的按下色初版写成 `background.withValues(alpha: 0.78)`，浅蓝底乘出来比原色更浅，按下时底色反而消失。

### 第 2.5 批（再续）：表单与按钮质感

TE 追加「可以提升下表单和按钮的质感吗」。判断是**质感的来源是分层，不是装饰**：改动前所有表面都是平的——输入框填充 `#F3F8FC` 与边框 `#E4EEF6` 只差 `0x0F`（等于没有边框），按钮是纯色平涂，光标还是默认的 Material 蓝紫。

- **新增 `AppField`**（`widget/ui.dart`），11 处输入框全部换过来（登录 4、编辑资料 3、发布 3；聊天输入框嵌在白色胶囊里，刻意不换）。核心原因是 `InputDecorator` 在 focus 变化时**瞬时重建**，border/fill 直接跳变——`inputDecorationTheme` 里改多少颜色都做不到"点亮"的过程，必须自己用 `AnimatedContainer` 画。四态配色表见 `docs/01` 第十节。
- **按钮加渐变与受光边**：`_ButtonFace` 给深/白胶囊各定一組常态与按下渐变，深色再叠一条 1px 顶部受光线。纯色没有方向信息，有了上亮下暗才有厚度。禁用态一律退回纯色。
- **全局**：`textSelectionTheme` 把光标、选区、手柄统一成品牌蓝（默认蓝紫在天蓝设计里很损质感）；`chipTheme` 的投影换品牌蓝辉光。

顺带修了两处不一致：`ChipThemeData` 没有 `selectedElevation` 参数（只有 `elevation` / `pressElevation`，选中态不单独控高度，已注明）；发布页的地标下拉框补了 `place` 图标和 `rSm` 圆角，跟上表单轮廓。

自造并在自查中修掉三处：`AppField` 外层结构写重（多套了一层 `Column` 与一个 `}`）；密码框替换时丢了 `onSubmitted`（已补回并加 `TextInputAction.go`）；错误行初版想让 `AnimatedContainer` 同时当背景和错误行，实际二者是父子关系。

## 第 3 批交付

四个页面，另有两处支撑层改动：`activity_card.dart` 的地址缩写提为 public（日程页要用，不复制第二份），`kVenues`（6 项地标）与 `ActivityState.tagPool`（8 个标签）从页面私有提为共享——两页各持一份，改一处就会漂移。

### 徽章墙 `badge`

三态口径与小程序 `badge.js` 逐字对齐：已解锁显示获得日期；未解锁且 `group != 'NONE'` 显示进度条 + `progress/target`；其余显示「未解锁」。`pct = target > 0 ? min(100, round(progress/target*100)) : 0`，`FULL` 组 `target=1` 也要出 `0/1`——徽章规则见 `docs/06`。

未解锁卡片用**渐变灰底而不是 `opacity`**：`opacity` 会把图标和文字一起洗掉，灰底至少保住图标轮廓。卡片底部固定高 30 的槽位（进度条或三态文案二选一），保证网格里每张卡齐高——`GridView` 的 `childAspectRatio` 按 `width / 182` 现算，写死比例在窄屏上会把文字截断。

顶部汇总卡的 earned / in-progress 数字用 `TweenAnimationBuilder` 弹出，与整体呼吸感口径一致。

### 信用明细 `credit-log`

顶部分数条按百分数绘制（`clamp(0,100)`），下面是规则卡与流水列表，加减分用彩色胶囊区分，末列带 `· 余 N`（`balanceAfter`）。

规则文案与小程序 RULES 逐字一致（5 条）。**已知缺口**：后端实际规则还有「取消报名 -1」「开始前 2 小时内取消 -3」「被确认到场 +3」（见 `docs/01` 信用分规则），小程序文案里没有这三条。迁移期保持两端一致，待 TE 拍板是否补文案再同步。

mock 侧 4 条种子流水，末条 `balanceAfter` 与 `me.creditScore`（90）对齐——分页数据与用户分数对不上，页面上就会显出「明明扣了分总分没动」的破绽。

### 我的日程 `schedule`

不新增仓储，复用 `ActivityState.organized / joined`（`loadMine(size: 100)`），页面内按 `dateKey`（`YYYY-MM-DD` 可直接字符串比较）分组，label 取 今天 / 明天 / 后天 / 周X / M月D日；未来组升序在前、过去组降序在后，与小程序时间轴方向一致。

筛选栏用 `AnimatedAlign(Alignment(-1 + index, 0))` + `FractionallySizedBox(1/3)` 做滑块，滑块 / 文字 / 点击区三层 Stack——文字层必须吃掉点击，滑块层 `IgnorePointer`，否则滑块会把点击吞掉。规则见 `docs/11`。

一处刻意偏离：某天「已结束」的判定用 `items.every(past)`，小程序用 `items[0].past`——后者会把「上午场已过、晚上还有局」的白天整片置灰。

### 活动编辑 `activity-edit`

**编辑接口是全量覆盖**：后端 `PUT /api/activity/{id}` 复用 `ActivityCreateRequest`，`saveImages` / `saveTags` 先删后插。所以编辑页**必须把已有 images / tags 原样回传**，少传一张等于删一张。回填时把 `venue` 拆成「地标 + 详细地址」两段（`splitVenue` 拆不开时返回 `(null, 原地址)`，不静默改成第一个地标）。

时间面板是自绘的区间双滑块（`showModalBottomSheet<_TimeRange>`）：30 分钟一档（`(ratio * 1440 / 30).round() * 30`），不支持跨天（起点 ≤ 终点 - 30，终点 ≥ 起点 + 30，兜底 +120 分钟），手柄命中判定「离哪头近算哪头」，轨道宽度由 `LayoutBuilder` 给。

`_baseDate` 单独存原日期：时间面板的日期 chips 只有「今天起 4 天」窗口，活动真实日期可能更远；用户没主动选日期时用它拼时间，避免日期被窗口截断。

约束与小程序一致：仅组织者、状态须 OPEN/FULL、`endTime > startTime`、`maxParticipants >= currentParticipants`。规则见 `docs/12`。

**配图区只删不加**：Flutter 侧选图要引 `image_picker`（原生插件），与「纯 Dart 包」约束冲突，迁移期与头像上传一并挂起。删除已有图必须走全量回传，这是删得掉的前提。

### 入口与跳转

详情页 AppBar 在「组织者 + OPEN/FULL」时出现编辑按钮，返回 `true` 后 `_load()` + `ActivityState.patch()` 双刷新。「我的」页四宫格入口（找搭子 / 我的日程 / 徽章墙 / 信用明细）全部接通：找搭子落到 `buddy_page`、我的日程落 `schedule`、徽章墙落 `badge`、信用明细落 `credit-log`。

## 第 4 批交付

两页收尾，外加组合根注册与详情页分享入口。后端契约与第 3 批完全一致（`BuddyController` / `POST /api/buddy` 等，见 `docs/03`），只加 Dart，不动 `server/`。

### 分享海报 `poster`

小程序那边的 canvas 2d + `saveImageToPhotosAlbum` 无法直接移植——Flutter 没有同等画布 API，且存相册要 `image_gallery_saver`（原生插件，与「纯 Dart 包」约束冲突）。改用 `CustomPainter` 复刻同一套版式 + `RepaintBoundary.toImage(pixelRatio)` 导出 PNG。版式口径逐字对齐 `docs/07`：750×1240 设计坐标、封面 `aspectFill` 裁切或渐变兜底 + 状态角标、标题两行截断、标签行（分类 / 状态 / 信用门槛）、信息三行、组织者行、虚线分隔、底部「微信小程序 / 搜「搭子」」引导块。

导出按显示宽度回算 `pixelRatio`：预览盒宽度写回 `_displayW`，`_save` 用 `_displayW / 750` 作缩放基准，导出分辨率与预览一致，不受父容器 `overflow:hidden` 影响（同文档 07 对小程序 `transform:scale` 的证伪）。封面走 `NetworkImage` 异步解码，4s 超时或失败回落渐变兜底，不卡白屏。

`dart:html` 的隔离沿用 `chat_socket` 的做法：非 web 用 `poster_download.dart`（`downloadPng` 返回 `false`，调用方退回到弹窗预览，长按可存），web 用 `poster_download_web.dart`（`Blob` + `AnchorElement` 触发浏览器下载）。条件导入 `if (dart.library.html) 'poster_download_web.dart'` 保证装机构建不引入 `dart:html`。

### 找搭子 `buddy`

双页签（匹配结果 / 我的需求），胶囊滑块 + `TabController` + `NeverScrollableScrollPhysics` 关横滑。匹配结果卡展示 `score`（转百分比）、距离、共同标签、后端给的 `reason`，以及「私聊 TA」——但 `ChatRoomPage` 目前只认 `groupId`（DM 页未落地），这枚按钮先 `toast` 兜底，作为已知缺口。我的需求卡可发布 / 关闭，发布面板复用 `AppField` 与 `ActivityState.categories / tagPool`。

匹配分算法不在前端（后端按「标签重合 0.5 + 距离 0.3 + 信用 0.2」加权）。mock 侧在 `MockStore` 实现同一公式：`matchBuddies` 按坐标过滤后算分排序，`buddyRequestsOf` 取我的需求，`closeBuddy` 置 `CLOSED`。演示坐标沿用 `ActivityState.demoLng(116.4610) / demoLat(39.9088)`（北京国贸），与活动流、小程序 `buddy.js` 同坐标；种子给 manman / chenmo / suxiao 各一条贴国贸坐标的需求，me 的标签设成「剧本杀 / 桌游」，页面一进来就有匹配内容且「共同标签」有东西显示。

组合根按硬约束在 `app_scope.dart` 同时注册 real 与 mock 两个 `BuddyRepository`，`app.dart` 注入 `BuddyState`，`profile_page` 的四宫格「找搭子」由 `toast` 兜底改为 `Navigator.push(BuddyPage())`。

### 详情页分享入口

`activity_detail_page.dart` 底部操作条**最左**加「分享」按钮（三点连线图标 + 文字，非 emoji，避免底部操作条被不同字体撑高，见 `docs/07`），点击 `push` 到 `PosterPage(activityId:)`。任何状态的活动都可分享，不受 OPEN/FULL 等条件约束。

## 两端必须一字不差的约定

| 项 | 值 | 位置 |
| --- | --- | --- |
| 标签预设池 | 26 个 | 小程序 `profile.js` 的 `TAG_SUGGESTIONS` ↔ Flutter `profile_page.dart` 的 `kTagSuggestions` |
| 标签数量上限 | 20 | 后端 `UserServiceImpl.MAX_TAGS`，两端各自也校验 |
| 自定义标签字数 | 10 | 两端各自校验 |
| 排序枚举 | `latest` / `hot` / `distance` | 后端 `ActivityController.sortBy` |

这类"两端同一份口径"的常量，改一处必须同步另一处，否则会出现"手机上删掉的标签在小程序里还在"这种很难复现的错觉。

## 未做项与理由

- **头像上传与编辑页配图新增**：Flutter 侧选图要引 `image_picker`，它是原生插件，与 `docs/01`「每个选型都要求是纯 Dart 包、或者干脆不引」的约束冲突。编辑页因此**只能删图不能加图**（删除走全量回传实现，不影响编辑流程），留到装机阶段和依赖策略一起定。
- **详情页分享入口**：已在第 4 批做完——底部操作条最左的「分享」按钮（自绘笔画图标，非 emoji）`push` 到 `PosterPage`。同时 `profile_page` 四宫格「找搭子」由 `toast` 兜底改为直接进 `BuddyPage`。
- **找搭子 `buddy`**：第 4 批已做完，含组合根 real/mock 双注册、mock 种子与匹配算法、详情页分享入口联动。唯一缺口：匹配卡上的「私聊 TA」因 Flutter 侧 `ChatRoomPage` 只认 `groupId`（DM 页未落地）先 `toast` 兜底，等 DM 页接通后补真实私聊跳转。
- **credit-log 规则文案缺口**：小程序 RULES 只有 5 条，缺后端实际的「取消 -1 / 2 小时内取消 -3 / 到场 +3」。迁移期保持逐字一致，待拍板补文案后两端同步。

第 1 批里的两条"等第 2 批"已在第 2 批还清：关注 / 粉丝计数现在可点进 `follow-list`，详情页组织者卡可点进 `user-profile`。第 1 批挂起的"详情页编辑入口"也已在第 3 批还清：组织者且 OPEN/FULL 时 AppBar 出现编辑按钮，落到 `activity-edit` 页。

## 验证

- `flutter analyze`：第 4 批合入后 **0 error**，剩 4 条 info（buddy_page 两处 `use_build_context_synchronously`，已用 `context.mounted` 兜住；poster_download_web 两处 `dart:html` 弃用提示，属 web 专用隔离文件的固有提示），均不阻断构建。前几批的零 issue 口径在 error 层面维持。
- 冒烟：本机 `flutter run -d edge` 起不来（沙箱拦 `reg.exe`，见下），改用 `flutter build web --release --no-web-resources-cdn` 出静态产物 + `python -m http.server 5180` 托管，在浏览器里走一遍。**注意 TE 说的"用 edge 调试"实际走的就是这条静态预览路径**——`flutter run -d edge|chrome|web-server` 在本机全废，`index.html` / `main.dart.js` 均 200。
- 第 3 批另做了一次数据层冒烟（临时脚本跑 mock 数据源，跑完即删）：徽章 8 枚 / 已解锁 2；流水 4 条且末条 `balanceAfter` 与 `me.creditScore` 一致；`splitVenue` 对已知地标返回下标+详细地址、对未知地址返回 `(null, 原地址)`；换一个用户看徽章墙为 1 枚（不是把同一份数据渲染两遍）。
- 第 4 批：`flutter build web --release` 全量编译通过（`√ Built build/web`，2026-10-16）。数据层冒烟脚本（临时、`MockStore.instance` 起 seed → `match` / `mine` / `create` / `close` 四步）**编译通过**，但本机 `flutter test` 的 test runner（flutter_tester）与 `flutter run -d edge` 同因沙箱拦本地 socket 起不来（`WebSocketException: Invalid WebSocket upgrade request`），未能在本机执行；逻辑正确性由全量 web 编译 + analyze 兜底。重点应在浏览器预览里走：海报封面兜底不白屏、导出 PNG 不崩；找搭子匹配卡分数降序、共同标签有内容、发布/关闭后"我的需求"即时变化。

第 2 批的冒烟清单：他人主页关注 / 取关（含断开后端看回滚）、关注粉丝列表两 tab 翻页与空态、通知列表点未读跳转并观察红点消失、底部消息 tab 红点 = 聊天未读 + 通知未读。手感返工的重点是按住 chip / 统计格看有无反馈、列表加载看骨架是否在扫、进出页面看入场是否还卡半拍。第 3 批的重点是：徽章三态各自长什么样、日程分组方向与过去态置灰、编辑页回填后直接提交（验全量回传有没有丢图丢标签）、时间面板拖两端与 30 分钟档位。

## Android SDK（装机前置，本次一并解决）

装机需要 Android SDK，而本机原先没有——`flutter doctor -v` 报 `Unable to locate Android SDK`，`ANDROID_HOME`/`ANDROID_SDK_ROOT` 均空，全盘也没有任何 SDK 目录。**`D:\Flutter` 是 Flutter SDK（施工队），不等于 Android SDK（工地上的专用工具）**，两者必须都有才能出 APK。

Flutter 3.47.7 的版本要求（取自 `packages/flutter_tools/lib/src/android/gradle_utils.dart`）：

| 项 | 值 |
| --- | --- |
| compileSdk / targetSdk | 36 |
| minSdk | 24 |
| ndkVersion | 28.2.13676358（按需再装） |

已装到 `D:\Android\Sdk`：cmdline-tools（`commandlinetools-win-15859902_latest.zip`，SHA-256 校验通过）、platform-tools、`platforms;android-36`、`build-tools;36.0.0`。`flutter config --android-sdk D:\Android\Sdk` 写入后，`flutter doctor` 的 Android 段已转 **`[√] Android toolchain - develop for Android devices (Android SDK version 36.0.0)`**。

NDK 暂时不装：`app/build.gradle.kts` 里 `ndkVersion = flutter.ndkVersion`（28.2.13676358），但这台机器磁盘只剩十几 G，而纯 Dart/Java 插件构成的工程在不出 native 产物时用不到它。等 `flutter build apk` 真的报 `NDK not configured` 再补，几百 M 不该先占着。

装机时还有两个必踩的坑，已在代码里处理：

1. `android/app/src/main/AndroidManifest.xml` 缺 `android:usesCleartextTraffic="true"`。Android 9+ 默认禁明文 HTTP，而本地后端是 `http://<局域网IP>:8099`，不开这一项真机上一请求就报 `CLEARTEXT communication not permitted`。
2. `Env.apiBase` 默认 `http://127.0.0.1:8099`，在真机上指向手机自己。必须用 `--dart-define=API_BASE=http://<电脑局域网IP>:8099` 覆盖。本机有 WSL 与 VMware 三张虚拟网卡，**要挑真实 WLAN 网段的地址**，传错网段手机连不上；另外防火墙需放行 8099。

## 过程中踩到的环境坑

- **PowerShell 的 `|` 喂不进 `.bat` 的 stdin**：`sdkmanager --licenses` 会一直停在 `Accept? (y/N)` 上挂住（实测挂了 5 分钟没动静）。改用 Git Bash 的 `yes | sdkmanager.bat --licenses` 才通过，8 个许可一次接受完。
- **一次性装多个组件会把 sdkmanager 卡死**：同批 `platform-tools` + `platforms;android-36` + `build-tools;36.0.0` 挂了 11 分钟无输出，掐掉后逐个装才走通。**更阴的是失败留下的痕迹**：`platforms/android-36/` 只剩一个 `.installer` 空壳，`flutter doctor` 于是报 `Android SDK file not found: ...\platforms\android-36\android.jar`——看起来像"SDK 没装对"，实际是**装了一半**。补装 `platforms;android-36` 一次就好（本次耗时 8 分 37 秒，`android.jar` 27.7 MB 落地）。判断方法：`find <platform 目录> -type f | wc -l`，只有 1 个文件就是空壳。
- **沙箱拦截 `Remove-Item -Recurse` / `rm -rf`**：解压 cmdline-tools 后清理临时目录、以及清掉上面那个空壳目录，都失败了（安全删除策略要求走回收站，回收站失败即拒绝降级删除）。**解压与移动本身是成功的**，别被这条错误带偏；空壳目录交给 sdkmanager 覆盖安装即可，不必先删。
- **沙箱拦截 `reg.exe`**：`flutter doctor` 的 `Windows Version` 与 `Connected device` 两项直接崩（`Flutter failed to run "reg query ..."`）。这是本机安全策略的黑名单，**无法从命令里绕过**，`flutter run -d edge` 也因此起不来（探测 Edge 版本要读注册表）。绕行方式：`flutter build web --release` 出静态产物 + 任意静态服务器托管，浏览器里看。若要用 `-d edge`/`-d chrome` 调试，需要把 `reg.exe` 从安全中心 → 命令安全 → 程序黑名单里移出。
- **Chrome 探测被路径里的 `Chrome` 带偏**：`flutter doctor` 报 `Cannot find Chrome executable at .\Google\Chrome\Application\chrome.exe`，而真实位置是 `D:\Chrome\Google\Chrome\Application\chrome.exe`——Flutter 探测时把路径中与产品同名的目录段切掉了。设 `CHROME_EXECUTABLE=D:\Chrome\Google\Chrome\Application\chrome.exe` 可修，本次没改（不影响装机，只影响 web 调试的设备探测）。
