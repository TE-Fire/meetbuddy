import '../../model/badge.dart';
import '../badge_repository.dart';
import 'mock_data.dart';

/// 内存徽章数据源。
///
/// 刻意不做成"读一份常量"：徽章墙要靠它区分已解锁 / 未解锁带进度 / 未解锁无进度
/// 三种画法，所以灌进 `MockStore` 的必须是**全部 8 枚**（见 mock_data 的注释）。
/// 只灌 2 枚已解锁的话，页面会误以为系统里总共就 2 枚。
class MockBadgeRepository implements BadgeRepository {
  MockBadgeRepository(this._store);

  final MockStore _store;

  @override
  Future<List<Badge>> mine() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _store.ensureSeeded();
    // 用 _store.me 而不是硬编码 1：换账号登录（mock 也支持多账号切换）时
    // 徽章墙要跟着变，写死就永远是阿发那 8 枚。
    return List<Badge>.of(_store.badgesOf(_store.me.id));
  }
}
