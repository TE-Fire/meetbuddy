import 'config/env.dart';
import 'repository/activity_repository.dart';
import 'repository/api_client.dart';
import 'repository/auth_repository.dart';
import 'repository/chat_repository.dart';
import 'repository/chat_socket.dart';
import 'repository/mock/mock_activity_repository.dart';
import 'repository/mock/mock_auth_repository.dart';
import 'repository/mock/mock_chat_repository.dart';
import 'repository/mock/mock_chat_socket.dart';
import 'repository/mock/mock_data.dart';
import 'repository/mock/mock_user_repository.dart';
import 'repository/real/real_activity_repository.dart';
import 'repository/real/real_auth_repository.dart';
import 'repository/real/real_chat_repository.dart';
import 'repository/real/real_chat_socket.dart';
import 'repository/real/real_user_repository.dart';
import 'repository/user_repository.dart';

/// 组合根。
///
/// `docs/01` 第八节定的规矩：**全项目只有这一处允许读 [Env.useMock]**，
/// 业务代码、页面、state 都只认 repository 接口。这样切换数据源只改这一行，
/// 也不会出现 `if (isMock)` 散落在页面里的情况。
class AppScope {
  AppScope({
    required this.api,
    required this.auth,
    required this.user,
    required this.activity,
    required this.chat,
    required this.socket,
    required this.usingMock,
  });

  final ApiClient api;
  final AuthRepository auth;
  final UserRepository user;
  final ActivityRepository activity;
  final ChatRepository chat;
  final ChatSocket socket;
  final bool usingMock;

  factory AppScope.build() {
    final api = ApiClient();
    if (Env.useMock) {
      final store = MockStore.instance..ensureSeeded();
      // 只建一个用户数据源实例：活动流要读它记录的上报坐标，
      // 建两份的话"开启就近筛选"写进 A、列表从 B 读，永远是 null。
      final userRepo = MockUserRepository(store);
      return AppScope(
        api: api,
        auth: MockAuthRepository(store),
        user: userRepo,
        activity: MockActivityRepository(store, userRepo),
        chat: MockChatRepository(store),
        socket: MockChatSocket(store),
        usingMock: true,
      );
    }
    return AppScope(
      api: api,
      auth: RealAuthRepository(api),
      user: RealUserRepository(api),
      activity: RealActivityRepository(api),
      chat: RealChatRepository(api),
      socket: RealChatSocket(),
      usingMock: false,
    );
  }
}
