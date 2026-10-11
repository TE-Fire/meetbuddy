/// 分页出参，形状与后端 PageVO 一致：{ list, total, page, size }。
///
/// 所有列表接口都用它，页面只写一套"下拉加载下一页"的逻辑。
class PageData<T> {
  PageData({
    required this.list,
    required this.total,
    required this.page,
    required this.size,
  });

  final List<T> list;
  final int total;
  final int page;
  final int size;

  bool get hasMore => page * size < total;

  factory PageData.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) item,
  ) {
    final raw = json['list'];
    return PageData<T>(
      list: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => item(e.cast<String, dynamic>()))
              .toList()
          : <T>[],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      size: (json['size'] as num?)?.toInt() ?? 20,
    );
  }

  factory PageData.empty() => PageData<T>(list: <T>[], total: 0, page: 1, size: 20);
}
