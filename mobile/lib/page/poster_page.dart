import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../app_scope.dart';
import '../config/env.dart';
import '../model/activity.dart';
import '../model/api_exception.dart';
import '../page/poster_download.dart'
    if (dart.library.html) 'poster_download_web.dart';
import '../widget/activity_card.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';

/// 活动分享海报。
///
/// 规则与坐标约定见 `docs/07-分享海报.md`。核心差异：小程序用 canvas 2d + `saveImageToPhotosAlbum`，
/// Flutter 这边没原生相册插件（约束见 docs/14 未做项），所以用 `CustomPainter` 复刻同一套版式，
/// 导出走 `RepaintBoundary.toImage` 生成 PNG——web 上触发浏览器下载，非 web 退回到弹窗预览。
/// 其余口径（封面兜底渐变、状态角标、两行标题截断、底部"微信小程序 / 搜「搭子」"引导块）逐字对齐。
class PosterPage extends StatefulWidget {
  const PosterPage({super.key, required this.activityId});

  final int activityId;

  @override
  State<PosterPage> createState() => _PosterPageState();
}

class _PosterPageState extends State<PosterPage> {
  PosterData? _data;
  ui.Image? _cover;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  double _displayW = 320;
  final GlobalKey _boundary = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await context.read<AppScope>().activity.detail(widget.activityId);
      if (!mounted) {
        return;
      }
      final data = PosterData.fromActivity(a);
      setState(() {
        _data = data;
        _loading = false;
      });
      // 封面图异步：先画（无封面兜底），图到位再整张重绘——网络图挂了也不留白。
      final url = data.coverUrl;
      if (url != null) {
        final img = await _loadCover(url);
        if (img != null && mounted) {
          setState(() => _cover = img);
        }
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// 4s 未回就放弃，避免海报一直卡着。
  Future<ui.Image?> _loadCover(String url) {
    final completer = Completer<ui.Image?>();
    var settled = false;
    void finish(ui.Image? v) {
      if (!settled) {
        settled = true;
        completer.complete(v);
      }
    }

    Timer(const Duration(seconds: 4), () => finish(null));
    try {
      final stream = NetworkImage(url).resolve(const ImageConfiguration());
      stream.addListener(
        ImageStreamListener(
          (info, _) => finish(info.image),
          onError: (_, _) => finish(null),
        ),
      );
    } catch (_) {
      finish(null);
    }
    return completer.future;
  }

  Future<void> _save() async {
    if (_saving || _data == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final boundary = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        return;
      }
      final scale = _displayW / 750;
      final factor = (MediaQuery.of(context).devicePixelRatio).clamp(1.0, 4096 / 1240);
      final image = await boundary.toImage(pixelRatio: factor / scale);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        return;
      }
      final list = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
      final ok = await downloadPng(list, '搭子活动海报.png');
      if (!mounted) {
        return;
      }
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('海报已生成，开始下载')));
      } else {
        // 非 web：没有原生写相册能力，退回到弹窗预览，长按图片可保存。
        await showDialog<void>(
          context: context,
          builder: (_) => _PreviewDialog(bytes: list),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('活动海报')),
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }
    final data = _data!;
    final width = (MediaQuery.of(context).size.width - 36).clamp(0.0, 420.0);
    // 预览盒宽度就是导出基准：build 里算出来后回写，_save 才能按真实显示尺寸算 pixelRatio。
    _displayW = width;
    final height = width * 1240 / 750;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F9FE),
      appBar: AppBar(title: const Text('活动海报')),
      body: Column(
        children: <Widget>[
          const SizedBox(height: 16),
          Text('存到相册，发到朋友圈或群里', style: const TextStyle(fontSize: 13, color: AppBrand.muted)),
          const SizedBox(height: 14),
          Center(
            child: RepaintBoundary(
              key: _boundary,
              child: CustomPaint(
                size: Size(width, height),
                painter: PosterPainter(data, _cover),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: PrimaryButton(
              text: _saving ? '正在生成…' : '保存 / 下载海报',
              height: 50,
              busy: _saving,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}

/// 海报展示数据。绘制要用的字段一次性算好，painter 里不再做判断。
class PosterData {
  const PosterData({
    required this.title,
    required this.statusText,
    required this.category,
    required this.icon,
    required this.timeText,
    required this.addrText,
    required this.slotsText,
    required this.creditRequired,
    required this.organizerFirst,
    required this.organizerNickname,
    required this.coverUrl,
  });

  final String title;
  final String statusText;
  final String category;
  final String icon;
  final String timeText;
  final String addrText;
  final String slotsText;
  final int creditRequired;
  final String organizerFirst;
  final String organizerNickname;
  final String? coverUrl;

  static const Map<String, String> _categoryIcons = <String, String>{
    '剧本杀': '🎭', '运动': '🏸', '探店': '🍜', '桌游': '🎲', '户外': '⛰️', '观影': '🎬', '其他': '✨',
  };

  static String _fmt(DateTime? t, {bool withDate = true}) {
    if (t == null) {
      return '待定';
    }
    String two(int v) => v.toString().padLeft(2, '0');
    final hm = '${two(t.hour)}:${two(t.minute)}';
    return withDate ? '${t.month}月${t.day}日 $hm' : hm;
  }

  factory PosterData.fromActivity(Activity a) {
    final slotsLeft = (a.maxParticipants - a.currentParticipants).clamp(0, a.maxParticipants);
    final timeText = a.endTime != null
        ? '${_fmt(a.startTime)} — ${_fmt(a.endTime, withDate: false)}'
        : _fmt(a.startTime);
    return PosterData(
      title: a.title,
      statusText: a.statusLabel,
      category: a.category,
      icon: _categoryIcons[a.category] ?? '✨',
      timeText: timeText,
      addrText: ActivityCard.shortAddress(a.address),
      slotsText: '${a.currentParticipants}/${a.maxParticipants}'
          '${slotsLeft > 0 ? ' · 还剩 $slotsLeft 个名额' : ' · 已满'}',
      creditRequired: a.creditRequired,
      organizerFirst: (a.organizerNickname ?? '?').isNotEmpty ? (a.organizerNickname!)[0] : '?',
      organizerNickname: a.organizerNickname ?? '匿名用户',
      coverUrl: Env.imgUrl(a.coverUrl),
    );
  }
}

/// 海报绘制。坐标固定在 750 × 1240 的设计栅格上，page 负责把画布缩放进预览盒（与小程序
/// `ctx.scale(dpr)` 同理，只是这里按显示比例缩，清晰度由 `toImage(pixelRatio)` 保住）。
class PosterPainter extends CustomPainter {
  PosterPainter(this.data, this.cover);

  final PosterData data;
  final ui.Image? cover;

  static const double w = 750;
  static const double h = 1240;
  static const double pad = 56;
  static const double coverH = 520;
  static const double cardTop = 460;
  static const double cardR = 48;
  static const double footBlock = 132;
  static const double footBottom = 50;
  static const double footTop = h - footBottom - footBlock; // 1058
  static const double dividerY = 1038;

  static const Color ink = Color(0xFF182028);
  static const Color ink2 = Color(0xFF3C4A56);
  static const Color muted = Color(0xFF93A1AD);
  static const Color brand = Color(0xFF189BE0);
  static const Color black = Color(0xFF171A1D);
  static const Color brandSoft = Color(0xFFE1F4FE);
  static const Color grassSoft = Color(0xFFEFF9E8);
  static const Color plainSoft = Color(0xFFF1F5F8);
  static const Color grassInk = Color(0xFF4E8F3C);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / w;
    canvas.save();
    canvas.scale(s, size.height / h);
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFFFFFFF));

    _drawCover(canvas);
    _drawCard(canvas);

    canvas.restore();
  }

  void _drawCover(Canvas canvas) {
    if (cover != null) {
      final ir = cover!.width / cover!.height;
      final br = w / coverH;
      double sx = 0, sy = 0, sw = cover!.width.toDouble(), sh = cover!.height.toDouble();
      if (ir > br) {
        sw = cover!.height * br;
        sx = (cover!.width - sw) / 2;
      } else {
        sh = cover!.width / br;
        sy = (cover!.height - sh) / 2;
      }
      canvas.drawImageRect(
        cover!,
        Rect.fromLTWH(sx, sy, sw, sh),
        const Rect.fromLTWH(0, 0, w, coverH),
        Paint(),
      );
    } else {
      final g = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(w, coverH),
        <Color>[const Color(0xFFDDF0FC), const Color(0xFFCFEAFB), const Color(0xFFEFF9E8)],
      );
      canvas.drawRect(const Rect.fromLTWH(0, 0, w, coverH), Paint()..shader = g);
      canvas.drawCircle(const Offset(w - 70, 60), 150, Paint()..color = const Color(0x8CCCCCCC));
      canvas.drawCircle(const Offset(80, coverH - 20), 160, Paint()..color = const Color(0x24FF0000));
      final icon = _tp(data.icon, fontSize: 120, weight: FontWeight.normal, color: const Color(0x554E8F3C));
      icon.layout();
      icon.paint(canvas, Offset(w / 2 - icon.width / 2, coverH / 2 - icon.height / 2));
    }
    _chip(canvas, data.statusText, pad, 44, black, const Color(0xFFFFFFFF), 26);
  }

  void _drawCard(Canvas canvas) {
    // 白卡：从封面里压上来，只有上边两角是圆角，底边贴到画布底。
    final cardPath = Path()
      ..moveTo(0, cardTop + cardR)
      ..lineTo(0, h)
      ..lineTo(w, h)
      ..lineTo(w, cardTop + cardR)
      ..arcToPoint(const Offset(w - cardR, cardTop), radius: const Radius.circular(cardR), clockwise: false)
      ..lineTo(cardR, cardTop)
      ..arcToPoint(const Offset(0, cardTop + cardR), radius: const Radius.circular(cardR), clockwise: false);
    canvas.drawShadow(cardPath, const Color(0x1F1F6696), 28, false);
    canvas.drawPath(cardPath, Paint()..color = const Color(0xFFFFFFFF));

    final innerW = w - pad * 2;

    // 标题：最多两行，超出以省略号收尾（TextPainter 原生支持）。
    final title = _tp(data.title, fontSize: 54, weight: FontWeight.bold, color: ink, maxLines: 2, ellipsis: '…');
    title.layout(maxWidth: innerW);
    final titleBase = cardTop + 110;
    title.paint(canvas, Offset(pad, titleBase));
    final titleBottom = titleBase + title.height + 16;

    // 标签行
    final chipY = titleBottom + 22;
    var cx = pad;
    cx += _chip(canvas, data.category, cx, chipY, grassSoft, grassInk, 26) + 16;
    cx += _chip(canvas, data.statusText, cx, chipY, brandSoft, brand, 26) + 16;
    if (data.creditRequired > 0) {
      _chip(canvas, '信用分 ≥ ${data.creditRequired}', cx, chipY, plainSoft, ink2, 26);
    }

    // 信息三行
    final rows = <List<String>>[
      <String>['时间', data.timeText],
      <String>['地点', data.addrText],
      <String>['名额', data.slotsText],
    ];
    final rowBase = chipY + 114;
    for (int i = 0; i < rows.length; i++) {
      final baseline = rowBase + i * 60;
      final label = _tp(rows[i][0], fontSize: 30, weight: FontWeight.bold, color: brand);
      label.layout();
      label.paint(canvas, Offset(pad, baseline - label.height));
      final value = _tp(rows[i][1], fontSize: 30, weight: FontWeight.normal, color: ink2, maxLines: 1, ellipsis: '…');
      value.layout(maxWidth: innerW - 96);
      value.paint(canvas, Offset(pad + 96, baseline - value.height));
    }

    // 组织者行（固定 y，标题一行/两行都不位移）。oy 必须 const double，否则
    // 下面 `const Offset(... oy ...)` 既拿不到编译期常量的 oy，又会把 int 喂给 double 形参。
    const double oy = 950;
    final g = ui.Gradient.linear(const Offset(pad, oy), const Offset(pad + 64, oy + 64), <Color>[const Color(0xFF59BCF5), brand]);
    canvas.drawCircle(Offset(pad + 32, oy + 32), 32, Paint()..shader = g);
    final first = _tp(data.organizerFirst, fontSize: 28, weight: FontWeight.bold, color: const Color(0xFFFFFFFF));
    first.layout();
    first.paint(canvas, Offset(pad + 32 - first.width / 2, oy + 32 - first.height / 2));
    final nick = _tp(data.organizerNickname, fontSize: 30, weight: FontWeight.bold, color: ink, maxLines: 1, ellipsis: '…');
    nick.layout(maxWidth: 400);
    nick.paint(canvas, Offset(pad + 88, oy + 18));
    final role = _tp('发起人', fontSize: 24, weight: FontWeight.normal, color: muted);
    role.layout();
    role.paint(canvas, Offset(pad + 88, oy + 52));

    // 虚线分隔
    _dashedLine(canvas, pad, dividerY, w - pad);

    _drawFooter(canvas);
  }

  void _drawFooter(Canvas canvas) {
    final brandT = _tp('搭子', fontSize: 36, weight: FontWeight.bold, color: ink);
    brandT.layout();
    brandT.paint(canvas, Offset(pad, footTop + 46 - brandT.height));
    final sub = _tp('找个搭子，一起把想做的事做了', fontSize: 22, weight: FontWeight.normal, color: muted);
    sub.layout();
    sub.paint(canvas, Offset(pad, footTop + 80 - sub.height));

    final bx = w - pad - footBlock;
    final by = footTop;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, footBlock, footBlock), const Radius.circular(28)),
      Paint()..color = black,
    );
    final t1 = _tp('微信小程序', fontSize: 18, weight: FontWeight.normal, color: const Color(0xFF8FA3B2));
    t1.layout();
    t1.paint(canvas, Offset(bx + footBlock / 2 - t1.width / 2, by + 52 - t1.height / 2));
    final t2 = _tp('搜「搭子」', fontSize: 21, weight: FontWeight.bold, color: const Color(0xFFFFFFFF));
    t2.layout();
    t2.paint(canvas, Offset(bx + footBlock / 2 - t2.width / 2, by + 86 - t2.height / 2));
  }

  /// 圆角胶囊 chip，返回占用宽度（含内边距），方便横向累加排布。
  double _chip(Canvas canvas, String text, double x, double y, Color bg, Color fg, double fontSize) {
    final tp = _tp(text, fontSize: fontSize, weight: FontWeight.bold, color: fg);
    tp.layout();
    final width = tp.width + 40;
    final height = 52.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, width, height), Radius.circular(height / 2)),
      Paint()..color = bg,
    );
    tp.paint(canvas, Offset(x + 20, y + (height - tp.height) / 2));
    return width;
  }

  void _dashedLine(Canvas canvas, double x1, double y, double x2) {
    final paint = Paint()
      ..color = const Color(0xFFE4EEF6)
      ..strokeWidth = 1;
    const dash = 8.0;
    const gap = 8.0;
    var x = x1;
    while (x < x2) {
      final next = (x + dash).clamp(x1, x2);
      canvas.drawLine(Offset(x, y), Offset(next, y), paint);
      x = next + gap;
    }
  }

  TextPainter _tp(
    String text, {
    required double fontSize,
    required FontWeight weight,
    required Color color,
    int maxLines = 1,
    String? ellipsis,
  }) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontSize, fontWeight: weight, color: color, height: 1.2),
        ),
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: ellipsis,
      );

  @override
  bool shouldRepaint(covariant PosterPainter old) => old.data != data || old.cover != cover;
}

/// 非 web 的保存兜底：把导出的 PNG 弹窗预览，长按可存。
class _PreviewDialog extends StatelessWidget {
  const _PreviewDialog({required this.bytes});

  final List<int> bytes;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('长按图片保存到相册', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Image.memory(Uint8List.fromList(bytes)),
          ],
        ),
      ),
    );
  }
}
