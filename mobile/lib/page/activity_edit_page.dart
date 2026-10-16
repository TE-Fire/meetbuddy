import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_scope.dart';
import '../model/activity.dart';
import '../model/activity_draft.dart';
import '../model/api_exception.dart';
import '../model/venue.dart';
import '../state/activity_state.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';

/// 编辑活动。规则与口径对齐小程序 `pages/activity-edit`，差异点在代码注释里标明。
///
/// 与发布页的分工：发布页用系统日期/时间选择器（两次点击搞定），
/// 本页用**区间滑动面板**——编辑场景的高频操作是"把 14:00–17:00 整体后移一小时"，
/// 拖两端比分别开两个选择器快，也不会出现开始晚于结束的中间态。
class ActivityEditPage extends StatefulWidget {
  const ActivityEditPage({super.key, required this.activityId});

  final int activityId;

  @override
  State<ActivityEditPage> createState() => _ActivityEditPageState();
}

class _ActivityEditPageState extends State<ActivityEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _address = TextEditingController();
  final _desc = TextEditingController();

  /// 加载中的活动详情。null = 还没拿到（加载中或失败）。
  Activity? _activity;
  String? _loadError;
  bool _submitting = false;

  Venue _venue = kVenues.first;
  String _category = ActivityState.categories.first;
  final Set<String> _tags = <String>{};
  int _maxParticipants = 6;
  int _creditRequired = 60;

  DateTime? _start;
  DateTime? _end;

  /// 原活动的真实日历日期（取到当天 0 点）。
  ///
  /// 时间面板只有"今天起 4 天"的窗口，而活动的日期可能是十天以后。
  /// 直接按窗口拼时间会把远日期截断成今天，所以原日期单独存一份，
  /// 用户没主动选日期时就用它——与小程序 `_baseDate` 同一用意。
  /// 面板每确认一次就刷新成新选日期的 0 点，所以"再开面板"回填的是上次的选择。
  DateTime? _baseDate;

  /// 人数下限：抬到当前已报名数，避免改小把人踢出去（后端同样会拦）。
  int _minParticipants = 1;

  /// 已有配图。Flutter 端没有选图插件，只能删不能加（见 [_imageSection]）。
  final List<String> _images = <String>[];

  @override
  void dispose() {
    _title.dispose();
    _address.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
    });
    try {
      final a = await context.read<AppScope>().activity.detail(widget.activityId);
      if (!mounted) return;
      // 地址按 " venue 名 · 详细地址" 拆回地标与详细地址；
      // 拆不开时地标保持默认、地址整体进输入框，不静默改用户的数据。
      final (venueIndex, addressDetail) = splitVenue(a.address);
      final start = a.startTime;
      final end = a.endTime;
      setState(() {
        _activity = a;
        _title.text = a.title;
        _desc.text = a.description ?? '';
        _address.text = addressDetail;
        _category = ActivityState.categories.contains(a.category) ? a.category : ActivityState.categories.first;
        _venue = venueIndex == null ? kVenues.first : kVenues[venueIndex];
        _tags
          ..clear()
          ..addAll(a.tags);
        _maxParticipants = a.maxParticipants;
        _creditRequired = a.creditRequired;
        _start = start;
        _end = end;
        _baseDate = start == null ? null : DateTime(start.year, start.month, start.day);
        _minParticipants = a.currentParticipants < 1 ? 1 : a.currentParticipants;
        if (_maxParticipants < _minParticipants) {
          _maxParticipants = _minParticipants;
        }
        _images
          ..clear()
          ..addAll(a.images);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    }
  }

  Future<void> _openTimePanel() async {
    final start = _start;
    final end = _end;
    if (start == null || end == null) {
      _toast('活动时间还没加载好');
      return;
    }
    final picked = await showModalBottomSheet<_TimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimeRangeSheet(
        initialStart: start,
        initialEnd: end,
        baseDate: _baseDate,
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _start = picked.start;
      _end = picked.end;
      // 面板确认的那一刻，用户选中的日期就成为新基准：
      // 之后再开面板，回填的是这次选的时间，不是最初加载的原日期。
      _baseDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    final title = _title.text.trim();
    if (title.length < 2) {
      _toast('至少写两个字');
      return;
    }
    final start = _start;
    final end = _end;
    if (start == null || end == null) {
      _toast('先把时间选上');
      return;
    }
    if (!end.isAfter(start)) {
      _toast('结束时间得晚于开始时间');
      return;
    }
    if (_maxParticipants < _minParticipants) {
      _toast('人数上限不能低于已报名的 $_minParticipants 人');
      return;
    }

    setState(() => _submitting = true);
    try {
      final detail = _address.text.trim();
      await context.read<AppScope>().activity.update(
            widget.activityId,
            ActivityDraft(
              title: title,
              category: _category,
              // 地址照小程序的格式拼回去：` venue 名 · 详细地址`，
              // 详细地址留空时退回地标自带地址——后端 GEO 与列表短地址都认这个格式。
              address: '${_venue.name} · ${detail.isEmpty ? _venue.address : detail}',
              lng: _venue.lng,
              lat: _venue.lat,
              startTime: start,
              endTime: end,
              maxParticipants: _maxParticipants,
              creditRequired: _creditRequired,
              description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
              coverUrl: _images.isEmpty ? null : _images.first,
              tags: _tags.toList(),
              images: _images.toList(),
            ),
          );
      if (!mounted) return;
      // 两个列表都可能含这条活动，都刷——只刷一个的话，另一个页面返回去是旧数据。
      final state = context.read<ActivityState>();
      await Future.wait(<Future<void>>[state.loadMine(), state.loadFeed()]);
      if (!mounted) return;
      _toast('已保存修改');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message, error: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _activity;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('编辑活动')),
      body: SkyBackground(
        height: 300,
        child: _loadError != null && a == null
            ? ErrorView(message: _loadError!, onRetry: _load)
            : a == null
                ? const Center(child: CircularProgressIndicator())
                : _form(context, a),
      ),
    );
  }

  Widget _form(BuildContext context, Activity a) {
    final closed = a.status != 'OPEN' && a.status != 'FULL';
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: <Widget>[
          const DisplayHeading(
            lead: '调整一下，',
            highlight: '改期改地',
            subtitle: '改完会即时同步到活动页，已报名的人会看到新信息',
            size: 23,
            align: TextAlign.left,
            crossAxisAlignment: CrossAxisAlignment.start,
          ),
          if (closed) ...<Widget>[
            const SizedBox(height: 14),
            _NoticeCard('活动已${a.statusLabel}，只能查看，不能修改'),
          ],
          const SizedBox(height: 18),

          _card(
            children: <Widget>[
              const _FieldLabel('局的名字', first: true),
              AppField(
                controller: _title,
                enabled: !closed,
                maxLength: 30,
                hintText: '例：国贸剧本杀·硬核本',
                validator: (v) => (v == null || v.trim().length < 2) ? '至少写两个字' : null,
              ),
            ],
          ),
          const SizedBox(height: 14),

          _card(
            children: <Widget>[
              const _FieldLabel('分类', first: true),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: <Widget>[
                  for (final c in ActivityState.categories)
                    ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: closed ? null : (_) => setState(() => _category = c),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 时间卡：整卡可点，点开底部区间面板
          _card(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const _FieldLabel('时间', first: true),
                  const SizedBox(width: 8),
                  const Text('点按设置', style: TextStyle(fontSize: 11.5, color: AppBrand.muted)),
                ],
              ),
              if (_start == null || _end == null)
                _TapRow(
                  text: '点此设置活动时间 ▾',
                  onTap: closed ? null : _openTimePanel,
                )
              else
                _TapRow(
                  onTap: closed ? null : _openTimePanel,
                  child: Row(
                    children: <Widget>[
                      _TimeCell(label: '开始', value: _pickText(_start!)),
                      const SizedBox(width: 10),
                      _TimeCell(label: '结束', value: _pickText(_end!)),
                      const SizedBox(width: 10),
                      _TimeCell(label: '时长', value: _durText(_start!, _end!), accent: true),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          _card(
            children: <Widget>[
              const _FieldLabel('地点', first: true),
              DropdownButtonFormField<Venue>(
                initialValue: _venue,
                decoration: const InputDecoration(
                  labelText: '附近地标（决定经纬度）',
                  prefixIcon: Icon(Icons.place_rounded, size: 20),
                ),
                borderRadius: BorderRadius.circular(AppBrand.rSm),
                icon: const Icon(Icons.expand_more_rounded, color: AppBrand.muted),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: AppBrand.ink,
                ),
                items: <DropdownMenuItem<Venue>>[
                  for (final v in kVenues)
                    DropdownMenuItem<Venue>(
                      value: v,
                      child: Text(v.fullName, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: closed ? null : (v) => setState(() => _venue = v ?? kVenues.first),
              ),
              const SizedBox(height: 12),
              AppField(
                controller: _address,
                enabled: !closed,
                hintText: '详细地址（选填）例：4F 星巴克门口集合',
              ),
            ],
          ),
          const SizedBox(height: 14),

          _card(
            children: <Widget>[
              const _FieldLabel('人数与门槛', first: true),
              _StepperRow(
                label: '最多 $_maxParticipants 人',
                value: _maxParticipants,
                min: _minParticipants,
                max: 200,
                enabled: !closed,
                onChanged: (v) => setState(() => _maxParticipants = v),
              ),
              _StepperRow(
                label: '信用分门槛 $_creditRequired',
                value: _creditRequired,
                min: 0,
                max: 100,
                step: 5,
                enabled: !closed,
                onChanged: (v) => setState(() => _creditRequired = v),
              ),
              if (_minParticipants > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '已有 $_minParticipants 人报名，人数上限不能低于此值',
                    style: const TextStyle(fontSize: 11.5, color: AppBrand.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          _card(
            children: <Widget>[
              const _FieldLabel('标签（可多选）', first: true),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: <Widget>[
                  for (final t in ActivityState.tagPool)
                    FilterChip(
                      label: Text(t),
                      selected: _tags.contains(t),
                      onSelected: closed
                          ? null
                          : (on) => setState(() {
                                if (on) {
                                  _tags.add(t);
                                } else {
                                  _tags.remove(t);
                                }
                              }),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          _card(
            children: <Widget>[
              AppField(
                controller: _desc,
                enabled: !closed,
                maxLines: 4,
                maxLength: 300,
                hintText: '集合方式、费用、需要带什么，写清楚能少一半的来回问',
              ),
            ],
          ),
          const SizedBox(height: 14),

          _imageSection(),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppBrand.primarySoft,
              borderRadius: BorderRadius.circular(AppBrand.rSm),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.info_outline_rounded, size: 18, color: AppBrand.primaryDeep),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '只改想动的字段即可，其余保持原样。提交后活动状态不变（仍是对外可报名）。',
                    style: TextStyle(fontSize: 12.5, color: AppBrand.primaryDeep, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          PrimaryButton(
            text: '保存修改',
            onPressed: closed ? null : (_submitting ? null : _submit),
            busy: _submitting,
          ),
        ],
      ),
    );
  }

  /// 配图区：只能删不能加。
  ///
  /// "加图"要走选图插件 + 分片上传，与本机"先浏览器预览、不引原生插件"的约束冲突，
  /// 留到装机阶段定（见 docs/14 未做项）。但**必须把已有图片原样回传**——
  /// 后端编辑是全量覆盖（`saveImages` 先删后插），少传一张就等于删一张。
  Widget _imageSection() {
    // 活动已开始/结束就不能编辑了，配图区跟着只读
    final readonly = _submitting ||
        (_activity != null && _activity!.status != 'OPEN' && _activity!.status != 'FULL');
    return _card(
      children: <Widget>[
        Row(
          children: <Widget>[
            const _FieldLabel('活动配图', first: true),
            const SizedBox(width: 8),
            const Text('第一张是封面', style: TextStyle(fontSize: 11.5, color: AppBrand.muted)),
          ],
        ),
        if (_images.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FC),
              borderRadius: BorderRadius.circular(AppBrand.rSm),
              border: Border.all(color: AppBrand.line, width: 1.4),
            ),
            child: const Text(
              '暂无配图（Flutter 端暂不支持上传，可到小程序添加）',
              style: TextStyle(fontSize: 12, color: AppBrand.muted),
            ),
          )
        else
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: _images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _ImageThumb(
                url: _images[i],
                cover: i == 0,
                onRemove: readonly ? null : () => setState(() => _images.removeAt(i)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppBrand.rLg),
          boxShadow: AppBrand.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );

  /// 面板回显用的完整文案：`10月17日 周五 14:00`。
  static String _pickText(DateTime t) {
    const week = <String>['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return '${t.month}月${t.day}日 ${week[t.weekday % 7]} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// 时长文案：`2小时` / `2小时 30分` / `45分钟`。与小程序 `_durText` 同口径。
  static String _durText(DateTime s, DateTime e) {
    var m = e.difference(s).inMinutes;
    if (m <= 0) return '';
    if (m >= 60) {
      final h = m ~/ 60;
      final rest = m % 60;
      return rest == 0 ? '$h小时' : '$h小时 $rest分';
    }
    return '$m分钟';
  }
}

/// 时间区间选择的结果。
class _TimeRange {
  const _TimeRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

/// 底部时间面板：日期 chips + 起止读数 + 一条可拖的区间轨道。
class _TimeRangeSheet extends StatefulWidget {
  const _TimeRangeSheet({
    required this.initialStart,
    required this.initialEnd,
    this.baseDate,
  });

  final DateTime initialStart;
  final DateTime initialEnd;

  /// 原活动的真实日期（编辑模式才有）。
  final DateTime? baseDate;

  @override
  State<_TimeRangeSheet> createState() => _TimeRangeSheetState();
}

class _TimeRangeSheetState extends State<_TimeRangeSheet> {
  /// 一天的总分钟数与拖动步长。30 分钟一档是小程序同款口径——
  /// 5 分钟一档在手机上根本拖不准，1 小时一档又太粗。
  static const int _total = 24 * 60;
  static const int _step = 30;

  static const List<String> _dateLabels = <String>['今天', '明天', '后天', '大后天'];
  static const List<String> _weekLabels = <String>['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

  late int _startMin;
  late int _endMin;

  /// 用户主动选过的日期；null = 用 [widget.baseDate]（编辑模式的原日期）。
  DateTime? _pickedDate;

  @override
  void initState() {
    super.initState();
    var s = widget.initialStart.hour * 60 + widget.initialStart.minute;
    var e = widget.initialEnd.hour * 60 + widget.initialEnd.minute;
    // 不支持跨天：结束不早于开始，兜底抬 2 小时（与小程序同口径）
    if (e <= s) {
      e = s + 120 > _total ? _total : s + 120;
      if (e <= s) {
        s = e - _step;
      }
    }
    _startMin = s;
    _endMin = e;
  }

  /// 生效日期：用户选过就用选的；否则用原活动日期（避免 4 天窗口把远日期截断）。
  DateTime get _effectiveDate {
    final picked = _pickedDate ?? widget.baseDate;
    if (picked != null) {
      return picked;
    }
    return _midnight(0);
  }

  static DateTime _midnight(int offsetDays) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offsetDays);
  }

  /// 日期 chips 的选中项。原日期不在 4 天窗口内时返回 -1（不选中任何一个）——
  /// 硬选一个会让用户以为日期被改了，其实生效的是另一个。
  int get _selectedDateIndex {
    final d = _pickedDate ?? widget.baseDate;
    if (d == null) {
      return 0;
    }
    final today = _midnight(0);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    return diff >= 0 && diff < _dateLabels.length ? diff : -1;
  }

  void _pickDate(int index) {
    setState(() => _pickedDate = _midnight(index));
  }

  void _resetDate() {
    setState(() => _pickedDate = null);
  }

  void _onDrag(int minutes, {required bool isStart}) {
    setState(() {
      if (isStart) {
        // 起点最远只能贴到终点前一步；再远就改成"终点不动、起点贴过去"
        var ns = minutes < _endMin - _step ? minutes : _endMin - _step;
        if (ns < 0) ns = 0;
        _startMin = ns;
      } else {
        var ne = minutes > _startMin + _step ? minutes : _startMin + _step;
        if (ne > _total) ne = _total;
        _endMin = ne;
      }
    });
  }

  void _confirm() {
    final base = _effectiveDate;
    Navigator.of(context).pop(
      _TimeRange(
        start: base.add(Duration(minutes: _startMin)),
        end: base.add(Duration(minutes: _endMin)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = _effectiveDate;
    final dateStr = '${date.month}月${date.day}日 ${_weekLabels[date.weekday % 7]}';
    final selected = _selectedDateIndex;

    return Padding(
      // 键盘弹出时把面板顶上去：isScrollControlled 只给权限，实际要减一个 inset
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppBrand.rLg)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppBrand.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Text(
                  '选择活动时间',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppBrand.ink),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const _SheetLabel('日期'),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: <Widget>[
                for (int i = 0; i < _dateLabels.length; i++)
                  ChoiceChip(
                    label: Text(_dateLabels[i]),
                    selected: selected == i,
                    onSelected: (_) => _pickDate(i),
                  ),
              ],
            ),
            // 原日期不在窗口内时说清楚，别让人以为 chips 坏了
            if (selected < 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.info_outline_rounded, size: 13, color: AppBrand.muted),
                    const SizedBox(width: 5),
                    const Expanded(
                      child: Text(
                        '原日期不在近四天，未改期前保持原日期',
                        style: TextStyle(fontSize: 11.5, color: AppBrand.muted),
                      ),
                    ),
                  ],
                ),
              )
            else if (_pickedDate != null && widget.baseDate != null && _sameDay(_pickedDate!, widget.baseDate!) == false)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _resetDate,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('恢复原日期', style: TextStyle(fontSize: 12)),
                ),
              ),
            const SizedBox(height: 14),

            _RangeTrack(
              startMin: _startMin,
              endMin: _endMin,
              startLabel: '$dateStr ${_minsText(_startMin)}',
              endLabel: _minsText(_endMin),
              onDrag: _onDrag,
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('0:00', style: TextStyle(fontSize: 11, color: AppBrand.muted)),
                Text('6:00', style: TextStyle(fontSize: 11, color: AppBrand.muted)),
                Text('12:00', style: TextStyle(fontSize: 11, color: AppBrand.muted)),
                Text('18:00', style: TextStyle(fontSize: 11, color: AppBrand.muted)),
                Text('24:00', style: TextStyle(fontSize: 11, color: AppBrand.muted)),
              ],
            ),
            const SizedBox(height: 18),

            Row(
              children: <Widget>[
                Expanded(
                  child: GhostButton(
                    text: '取消',
                    height: 48,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    text: '确定',
                    height: 48,
                    onPressed: _confirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _minsText(int m) {
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final mm = (m % 60).toString().padLeft(2, '0');
    return '$h:$mm';
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppBrand.ink2),
          ),
        ),
      );
}

/// 区间轨道：一条底槽 + 一段蓝色填充 + 两个可拖手柄 + 顶部两个时刻标签。
///
/// 拖动逻辑全部在这里，面板只管分钟数。手柄命中判定用"离哪头近算哪头"，
/// 省得在小屏幕上精确抓一个 26px 的圆片——小程序只认手柄上的 touchstart，
/// 桌面浏览器里用鼠标拖那么小的目标很别扭。
class _RangeTrack extends StatefulWidget {
  const _RangeTrack({
    required this.startMin,
    required this.endMin,
    required this.startLabel,
    required this.endLabel,
    required this.onDrag,
  });

  final int startMin;
  final int endMin;
  final String startLabel;
  final String endLabel;

  /// 拖动过程中的新分钟数。[isStart] 标明拖的是哪一头。
  final void Function(int minutes, {required bool isStart}) onDrag;

  @override
  State<_RangeTrack> createState() => _RangeTrackState();
}

class _RangeTrackState extends State<_RangeTrack> {
  static const int _total = 24 * 60;
  static const int _step = 30;

  /// 正在拖的是起点还是终点；null = 没在拖。
  bool? _draggingStart;

  /// 轨道宽度，由 LayoutBuilder 给。0 = 还没布局，忽略拖动。
  double _trackWidth = 0;

  int _minutesAt(double dx) {
    final ratio = (_trackWidth <= 0 ? 0 : dx / _trackWidth).clamp(0.0, 1.0);
    // 对齐到 30 分钟一档。四舍五入会让 44:59 这种时刻不存在，这是特性：
    // 活动时间本来就是粗粒度的。
    return (ratio * _total / _step).round() * _step;
  }

  void _update(double dx, {required bool isStart}) {
    widget.onDrag(_minutesAt(dx), isStart: isStart);
  }

  /// 落点离哪头近就拖哪头。
  bool _nearestIsStart(double dx) {
    final sx = widget.startMin / _total * _trackWidth;
    final ex = widget.endMin / _total * _trackWidth;
    return (dx - sx).abs() <= (ex - dx).abs();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _trackWidth = constraints.maxWidth;
        final startPct = widget.startMin / _total;
        final endPct = widget.endMin / _total;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _update(d.localPosition.dx, isStart: _nearestIsStart(d.localPosition.dx)),
          onHorizontalDragStart: (d) {
            _draggingStart = _nearestIsStart(d.localPosition.dx);
          },
          onHorizontalDragUpdate: (d) {
            final isStart = _draggingStart ?? true;
            _update(d.localPosition.dx, isStart: isStart);
          },
          onHorizontalDragEnd: (_) => _draggingStart = null,
          onHorizontalDragCancel: () => _draggingStart = null,
          child: SizedBox(
            height: 64,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // 顶部的两个时刻标签，各自跟着自己的手柄
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 20,
                  child: IgnorePointer(
                    child: Stack(
                      children: <Widget>[
                        _TrackLabel(text: widget.startLabel, pct: startPct),
                        _TrackLabel(text: widget.endLabel, pct: endPct, alignEnd: true),
                      ],
                    ),
                  ),
                ),
                // 底槽
                Positioned(
                  left: 0,
                  right: 0,
                  top: 30,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF4F9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                // 蓝色填充
                Positioned(
                  left: constraints.maxWidth * startPct,
                  right: constraints.maxWidth * (1 - endPct),
                  top: 30,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppBrand.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                // 0/25/50/75/100 五个刻度，压在底槽上
                for (final pct in <double>[0, 0.25, 0.5, 0.75, 1])
                  Positioned(
                    left: constraints.maxWidth * pct - 1,
                    top: 27,
                    width: 2,
                    height: 14,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                // 两个手柄
                _Handle(
                  pct: startPct,
                  width: constraints.maxWidth,
                  dragging: _draggingStart == true,
                ),
                _Handle(
                  pct: endPct,
                  width: constraints.maxWidth,
                  dragging: _draggingStart == false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 手柄：白圆 + 蓝边 + 投影。拖动中放大一点，让"我抓着它"有反馈。
class _Handle extends StatelessWidget {
  const _Handle({required this.pct, required this.width, required this.dragging});

  final double pct;
  final double width;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final size = dragging ? 30.0 : 26.0;
    return Positioned(
      left: width * pct - size / 2,
      top: 30 + 4 - size / 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppBrand.primary, width: 2.5),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x3338B2F2), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
      ),
    );
  }
}

/// 轨道上方的时刻标签。两端都可能在屏幕边上，所以贴左端的标签向左对齐、
/// 贴右端的向右对齐，避免被裁掉。
class _TrackLabel extends StatelessWidget {
  const _TrackLabel({required this.text, required this.pct, this.alignEnd = false});

  final String text;
  final double pct;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(-1 + pct * 2, 0),
      child: FractionallySizedBox(
        // 不放宽到全轨道：两个标签都可能在中点附近，按全宽算会互相压
        widthFactor: 0.5,
        child: Text(
          text,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          maxLines: 1,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppBrand.ink2),
        ),
      ),
    );
  }
}

/// 整卡可点的一行（时间卡的两种形态共用）。
class _TapRow extends StatelessWidget {
  const _TapRow({required this.onTap, this.text, this.child});

  final VoidCallback? onTap;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8FC),
          borderRadius: BorderRadius.circular(AppBrand.rSm),
          border: Border.all(color: AppBrand.line, width: 1.4),
        ),
        child: child ??
            Row(
              children: <Widget>[
                const Icon(Icons.event_rounded, size: 18, color: AppBrand.primary),
                const SizedBox(width: 8),
                Text(
                  text ?? '',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppBrand.muted),
                ),
              ],
            ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.label, required this.value, this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppBrand.muted)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accent ? AppBrand.primaryDeep : AppBrand.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// 步进器一行：`− 数值 +`。编辑页用步进器而不是滑块——
/// 人数和信用分都是整数档位，滑块还要防"拖过已报名数"，按钮更直白。
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.enabled = true,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDown = enabled && value - step >= min;
    final canUp = enabled && value + step <= max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppBrand.ink2),
            ),
          ),
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: canDown,
            onTap: canDown ? () => onChanged(value - step) : null,
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppBrand.ink),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: canUp,
            onTap: canUp ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.enabled, this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      scale: 0.88,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppBrand.primarySoft : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: enabled ? AppBrand.primary.withValues(alpha: 0.35) : AppBrand.line),
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled ? AppBrand.primaryDeep : AppBrand.muted,
        ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.url, required this.cover, this.onRemove});

  final String url;
  final bool cover;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppBrand.rSm),
          child: Image.network(
            url,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            // 图挂了给个占位底色，别留白块——这页在编辑态，坏图很显眼
            errorBuilder: (_, _, _) => Container(
              width: 84,
              height: 84,
              color: const Color(0xFFEDF4F9),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, size: 20, color: AppBrand.muted),
            ),
          ),
        ),
        if (cover)
          const Positioned(
            left: 4,
            bottom: 4,
            child: _CoverTag(),
          ),
        if (onRemove != null)
          Positioned(
            right: -6,
            top: -6,
            child: PressableScale(
              onTap: onRemove,
              scale: 0.85,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppBrand.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _CoverTag extends StatelessWidget {
  const _CoverTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppBrand.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '封面',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(AppBrand.rSm),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.lock_outline_rounded, size: 17, color: Color(0xFFC77A2A)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFC77A2A), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// 表单小节标题：品牌蓝小方块 + 加粗文字。
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 18, bottom: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppBrand.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppBrand.ink),
            ),
          ],
        ),
      );
}
