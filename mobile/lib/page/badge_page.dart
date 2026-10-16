import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/badge.dart' as model;
import '../state/badge_state.dart';
import '../widget/state_views.dart';
import '../widget/ui.dart';

/// 我的勋章墙。规则见 `docs/06-成就勋章与个人主页.md`。
///
/// 入口在「我的」页的四宫格（与小程序 `/pages/badge/badge` 对齐）。
/// 三态画法与小程序逐字对齐：已解锁 → 获得日期；未解锁且有进度组 → 进度条 +
/// `n/target`；`NONE` 组未解锁 → 「未解锁」（首次型徽章没有"进行中"）。
class BadgePage extends StatefulWidget {
  const BadgePage({super.key});

  @override
  State<BadgePage> createState() => _BadgePageState();
}

class _BadgePageState extends State<BadgePage> {
  @override
  void initState() {
    super.initState();
    // 进页面就重拉：徽章可能在别的页面上刚解锁（报名/组局是即时评定的），
    // 走 provider 的缓存会看到旧进度。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BadgeState>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BadgeState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('我的勋章')),
      body: SkyBackground(
        child: RefreshIndicator(
          onRefresh: state.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
            children: <Widget>[
              _SummaryCard(earned: state.earned, total: state.items.length),
              const SizedBox(height: 18),
              const SectionHeader('全部勋章'),
              const SizedBox(height: 12),
              if (state.loading && state.items.isEmpty)
                const SkeletonList(rows: 3)
              else if (state.items.isEmpty)
                EmptyView(
                  title: '暂无勋章数据',
                  hint: '下拉刷新试试',
                  icon: Icons.military_tech_outlined,
                )
              else
                _BadgeGrid(badges: state.items),
              const SizedBox(height: 18),
              const Text(
                '报名、首次组局即时获得；其余在活动结束后自动评定，达成会发通知',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppBrand.muted, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部计数卡。数字本身是主角，右侧压一枚半透明奖牌做氛围。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.earned, required this.total});

  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rLg),
        boxShadow: AppBrand.card,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    // 计数变化时数字弹一下：徽章墙唯一的"奖励时刻"就在这一下上
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: earned.toDouble()),
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutBack,
                      builder: (context, t, _) => Text(
                        t.round().toString(),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: AppBrand.ink,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ $total',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppBrand.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  '已获得勋章',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppBrand.ink2),
                ),
                const SizedBox(height: 4),
                const Text(
                  '报名、组局、守约，都会沉淀成勋章',
                  style: TextStyle(fontSize: 12, color: AppBrand.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 纯装饰：放底层文字底下会糊，直接当贴纸放右边
          const Text('🏆', style: TextStyle(fontSize: 52)),
        ],
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.badges});

  final List<model.Badge> badges;

  @override
  Widget build(BuildContext context) {
    // 卡片高度按内容定死（图标 + 名称 + 两行描述 + 底部槽），宽度由屏宽均分，
    // 所以 aspectRatio 现算——写死值在窄屏上会把描述挤成一行。
    final width = (MediaQuery.sizeOf(context).width - 36 - 10) / 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: width / 182,
      ),
      itemCount: badges.length,
      itemBuilder: (context, i) => StaggeredIn(
        index: i,
        child: _BadgeCard(badge: badges[i]),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final model.Badge badge;

  /// 获得日期文案。口径与小程序 `utils/format.js` 的 `fmtTime` 逐字对齐
  /// （`X月X日 HH:MM`）——同一个徽章在两端显示成两个时间，比格式不好看严重得多。
  static String _dateText(DateTime? t) {
    if (t == null) {
      return '';
    }
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${t.month}月${t.day}日 $hm';
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = badge.unlocked;
    // NONE 组是"首次"型一次性徽章，没有"进行中"可言，未解锁就只写「未解锁」；
    // FULL 组 target=1 也要展示 0/1——它与小程序 showProgress 同口径。
    final showProgress = !unlocked && badge.group != 'NONE';
    final pct = badge.target > 0
        ? (badge.progress / badge.target * 100).round().clamp(0, 100)
        : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBrand.rMd),
        boxShadow: AppBrand.cardSm,
        // 未解锁整卡压灰：不用 opacity（会把文字一起淡掉，对比度不够），
        // 用一层极淡的灰蓝罩住，文字颜色单独降档。
        gradient: unlocked
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFFF7FAFC), Color(0xFFF1F5F9)],
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: unlocked ? AppBrand.primarySoft : const Color(0xFFEDF1F5),
              borderRadius: BorderRadius.circular(13),
            ),
            // 已解锁的 emoji 保持原色，未解锁的去色 + 压淡——"差一点"的感觉
            child: Text(
              badge.icon ?? '🎖️',
              style: TextStyle(
                fontSize: 22,
                decoration: TextDecoration.none,
                color: unlocked ? null : const Color(0x6093A1AD),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            badge.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: unlocked ? AppBrand.ink : AppBrand.ink2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            badge.desc ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppBrand.muted, height: 1.45),
          ),
          const SizedBox(height: 8),
          // 底部槽：三态之一。给固定高度，卡片才一般高
          SizedBox(
            height: 30,
            child: Align(
              alignment: Alignment.centerLeft,
              child: unlocked
                  ? Row(
                      children: <Widget>[
                        const Icon(Icons.check_circle_rounded, size: 13, color: AppBrand.grassDeep),
                        const SizedBox(width: 4),
                        Text(
                          '${_dateText(badge.unlockedAt)} 获得',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppBrand.grassDeep,
                          ),
                        ),
                      ],
                    )
                  : showProgress
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: pct / 100),
                                duration: const Duration(milliseconds: 560),
                                curve: Curves.easeOutCubic,
                                builder: (context, t, _) => LinearProgressIndicator(
                                  value: t,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFEDF4F9),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppBrand.primary),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${badge.progress}/${badge.target}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppBrand.primaryDeep,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          '未解锁',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppBrand.muted,
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
