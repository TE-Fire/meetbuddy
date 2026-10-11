import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_scope.dart';
import '../model/activity_draft.dart';
import '../model/api_exception.dart';
import '../state/activity_state.dart';
import '../widget/ui.dart';

/// 发布活动。
///
/// 坐标没有走地图选点（那要引地图 SDK + 原生定位，与本机"先浏览器预览"的约束冲突），
/// 改成"选一个地标 + 填详细地址"，地标负责给 GEO 一个真实的经纬度。
/// 后端的 GEO 匹配、半径筛选因此都是真跑，只是取点方式简化了。
class ActivityCreatePage extends StatefulWidget {
  const ActivityCreatePage({super.key});

  @override
  State<ActivityCreatePage> createState() => _ActivityCreatePageState();
}

class _Venue {
  const _Venue(this.name, this.address, this.lng, this.lat);

  final String name;
  final String address;
  final double lng;
  final double lat;
}

class _ActivityCreatePageState extends State<ActivityCreatePage> {
  static const List<_Venue> _venues = <_Venue>[
    _Venue('国贸商城', '朝阳区建国门外大街 1 号', 116.4610, 39.9088),
    _Venue('三里屯太古里', '朝阳区三里屯路 19 号', 116.4550, 39.9330),
    _Venue('奥林匹克森林公园', '朝阳区科荟路 33 号', 116.3920, 40.0200),
    _Venue('五道口购物中心', '海淀区成府路 28 号', 116.3370, 39.9930),
    _Venue('南锣鼓巷', '东城区南锣鼓巷', 116.4040, 39.9370),
    _Venue('常营体育公园', '朝阳区常营北路', 116.5900, 39.9250),
  ];

  static const List<String> _tagPool = <String>[
    '新手友好', '硬核', '深夜局', 'AA制', '免费', '带装备', '轻运动', '拍照',
  ];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _address = TextEditingController();
  final _desc = TextEditingController();

  _Venue _venue = _venues.first;
  String _category = ActivityState.categories.first;
  DateTime? _start;
  DateTime? _end;
  int _maxParticipants = 6;
  double _creditRequired = 60;
  final Set<String> _tags = <String>{};
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _address.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final base = (isStart ? _start : _end) ?? now.add(Duration(hours: isStart ? 1 : 3));
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: isStart ? '选择开始日期' : '选择结束日期',
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: isStart ? '选择开始时间' : '选择结束时间',
    );
    if (time == null || !mounted) {
      return;
    }
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end == null || !_end!.isAfter(picked)) {
          _end = picked.add(const Duration(hours: 2));
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_start == null || _end == null) {
      _toast('先把时间选上');
      return;
    }
    if (!_end!.isAfter(_start!)) {
      _toast('结束时间得晚于开始时间');
      return;
    }

    setState(() => _submitting = true);
    try {
      final created = await context.read<AppScope>().activity.create(
            ActivityDraft(
              title: _title.text.trim(),
              category: _category,
              description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
              address: '${_venue.name} · ${_address.text.trim().isEmpty ? _venue.address : _address.text.trim()}',
              lng: _venue.lng,
              lat: _venue.lat,
              startTime: _start!,
              endTime: _end!,
              maxParticipants: _maxParticipants,
              creditRequired: _creditRequired.round(),
              tags: _tags.toList(),
            ),
          );
      if (!mounted) return;
      // 回到列表让它重新拉一次，新活动立刻出现在最上面
      await context.read<ActivityState>().loadFeed();
      if (!mounted) return;
      Navigator.of(context).pop(true);
      debugPrint('created activity ${created.id}, group ${created.groupId}');
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('发起活动')),
      body: SkyBackground(
        height: 320,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: <Widget>[
              const DisplayHeading(
                lead: '说出想法，',
                highlight: '一键组局',
                subtitle: '发布后即刻同步给附近的搭子',
                size: 23,
                align: TextAlign.left,
                crossAxisAlignment: CrossAxisAlignment.start,
              ),
              const SizedBox(height: 18),

              _card(
                children: <Widget>[
                  TextFormField(
                    controller: _title,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: '活动标题',
                      hintText: '例：国贸剧本杀·硬核本',
                    ),
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
                          onSelected: (_) => setState(() => _category = c),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _card(
                children: <Widget>[
                  const _FieldLabel('时间', first: true),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _TimeBox(
                          label: '开始',
                          value: _start,
                          onTap: () => _pickDateTime(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TimeBox(
                          label: '结束',
                          value: _end,
                          onTap: () => _pickDateTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _card(
                children: <Widget>[
                  const _FieldLabel('地点', first: true),
                  DropdownButtonFormField<_Venue>(
                    initialValue: _venue,
                    decoration: const InputDecoration(labelText: '附近地标（决定经纬度）'),
                    items: <DropdownMenuItem<_Venue>>[
                      for (final v in _venues)
                        DropdownMenuItem<_Venue>(
                          value: v,
                          child: Text('${v.name} · ${v.address}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _venue = v ?? _venues.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: '详细地址（选填）',
                      hintText: '例：4F 星巴克门口集合',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _card(
                children: <Widget>[
                  const _FieldLabel('人数与门槛', first: true),
                  _SliderRow(
                    label: '最多 $_maxParticipants 人',
                    value: _maxParticipants.toDouble(),
                    min: 2,
                    max: 30,
                    divisions: 28,
                    display: '$_maxParticipants',
                    onChanged: (v) => setState(() => _maxParticipants = v.round()),
                  ),
                  _SliderRow(
                    label: '信用分门槛 ${_creditRequired.round()}',
                    value: _creditRequired,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    display: '${_creditRequired.round()}',
                    onChanged: (v) => setState(() => _creditRequired = v),
                  ),
                  const _FieldLabel('标签（可多选）'),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: <Widget>[
                      for (final t in _tagPool)
                        FilterChip(
                          label: Text(t),
                          selected: _tags.contains(t),
                          onSelected: (on) => setState(() => on ? _tags.add(t) : _tags.remove(t)),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _card(
                children: <Widget>[
                  TextFormField(
                    controller: _desc,
                    maxLines: 4,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: '活动介绍（选填）',
                      alignLabelWithHint: true,
                      hintText: '集合方式、费用、需要带什么，写清楚能少一半的来回问',
                    ),
                  ),
                ],
              ),
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
                        '发布成功会同时建好群聊，你自动是群主；之后别人一报名就进群。',
                        style: TextStyle(fontSize: 12.5, color: AppBrand.primaryDeep, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              PrimaryButton(
                text: '发布活动',
                onPressed: _submitting ? null : _submit,
                busy: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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

/// 带数值滑块的一行。
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppBrand.ink2),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppBrand.primarySoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                display,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.primaryDeep,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: display,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? '选择时间'
        : '${value!.month}月${value!.day}日 '
            '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}';
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppBrand.rSm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F8FC),
            borderRadius: BorderRadius.circular(AppBrand.rSm),
            border: Border.all(
              color: value == null ? const Color(0xFFE4EEF6) : AppBrand.primary.withValues(alpha: 0.5),
              width: 1.4,
            ),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.event_rounded, size: 18, color: AppBrand.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: const TextStyle(fontSize: 11.5, color: AppBrand.muted)),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: value == null ? AppBrand.muted : AppBrand.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
