import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/credit_log.dart';
import '../state/credit_log_state.dart';
import '../state/session_state.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';

/// 信用分明细。规则见 `docs/03-接口契约.md` 的 `/credit/logs`。
///
/// 入口在「我的」页四宫格（与小程序 `pages/credit-log` 对齐）。
/// 当前分取 [SessionState.me] 的 `creditScore`——登录时就带在 /user/me 里，
/// 不为一个数字再发一次请求；流水列表才是这个页面的主体。
class CreditLogPage extends StatefulWidget {
  const CreditLogPage({super.key});

  @override
  State<CreditLogPage> createState() => _CreditLogPageState();
}

class _CreditLogPageState extends State<CreditLogPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CreditLogState>().refresh();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 260) {
      context.read<CreditLogState>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CreditLogState>();
    final me = context.watch<SessionState>().me;
    final score = me?.creditScore;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('信用明细')),
      body: SkyBackground(
        child: RefreshIndicator(
          onRefresh: state.refresh,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
            children: <Widget>[
              _ScoreCard(score: score),
              const SizedBox(height: 14),
              const _RulesCard(),
              const SizedBox(height: 20),
              const SectionHeader('变动记录'),
              const SizedBox(height: 12),
              if (state.loading && state.items.isEmpty)
                const SkeletonList(rows: 4)
              else if (state.items.isEmpty)
                EmptyView(
                  title: '还没有变动记录',
                  hint: '正常履约不掉分，保持 100 分就是最好的状态',
                  icon: Icons.military_tech_outlined,
                )
              else
                _LogList(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

/// 当前分卡片。分数条按百分数画——信用分上限就是 100。
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rLg),
        boxShadow: AppBrand.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '当前信用分',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppBrand.muted),
          ),
          const SizedBox(height: 4),
          Text(
            score == null ? '—' : '$score',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: AppBrand.ink,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: (score ?? 0) / 100),
              duration: const Duration(milliseconds: 560),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => LinearProgressIndicator(
                value: t.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFEDF4F9),
                valueColor: const AlwaysStoppedAnimation<Color>(AppBrand.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '满值 100，低于活动门槛时无法报名',
            style: TextStyle(fontSize: 12, color: AppBrand.muted),
          ),
        ],
      ),
    );
  }
}

/// 规则文案。与小程序 `pages/credit-log/credit-log.js` 的 `RULES` 逐字一致——
/// 这是"分从哪来、到哪去"的说明，两端措辞不同会被当成两套规则。
///
/// 已知缺口：后端实际还有「取消报名 -1 / 开始前 2 小时内取消 -3 / 确认到场 +3」
/// 三条（见 `SignupTxService`），小程序这份清单没有列。迁移期先保持逐字一致，
/// 待产品确认后两端一起补。
const List<String> _kCreditRules = <String>[
  '新用户初始 100 分，正常履约不掉分；',
  '报名未取消且未出席，扣 10 分；',
  '发布违规活动被举报成立，扣 30 分；',
  '被他人举报且查实，扣 20 分；',
  '信用分低于活动门槛时将无法报名该活动。',
];

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rMd),
        boxShadow: AppBrand.cardSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppBrand.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                '分怎么来、怎么走',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppBrand.ink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final rule in _kCreditRules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '· $rule',
                style: const TextStyle(fontSize: 12.5, color: AppBrand.ink2, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({required this.state});

  final CreditLogState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppBrand.rMd),
            boxShadow: AppBrand.cardSm,
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < state.items.length; i++)
                _LogTile(
                  log: state.items[i],
                  showDivider: i != state.items.length - 1,
                ),
              if (state.loadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              else if (!state.finished)
                // 触底自动加载之外的兜底：滚动监听有 260px 的预取窗口，
                // 键盘弹出把列表顶短时可能来不及触发，留一个手动入口。
                TextButton(
                  onPressed: state.loadMore,
                  child: const Text('加载更多'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, required this.showDivider});

  final CreditLog log;
  final bool showDivider;

  /// 时间文案。口径与小程序 `utils/format.js` 的 `fmtTime` 逐字对齐（`X月X日 HH:MM`）。
  static String _timeText(DateTime? t) {
    if (t == null) {
      return '';
    }
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${t.month}月${t.day}日 $hm';
  }

  @override
  Widget build(BuildContext context) {
    final plus = log.plus;
    final accent = plus ? AppBrand.grassDeep : AppBrand.hot;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 加减分用彩色胶囊数字，比纯文字"+"号更抓眼——扣分尤其要看得见
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: plus ? AppBrand.grassSoft : const Color(0xFFFFEDF1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  log.valueText,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      log.reason,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppBrand.ink,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _timeText(log.createdAt) +
                          (log.balanceAfter != null ? ' · 余 ${log.balanceAfter}' : ''),
                      style: const TextStyle(fontSize: 11.5, color: AppBrand.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 16, endIndent: 16, color: AppBrand.line),
      ],
    );
  }
}
