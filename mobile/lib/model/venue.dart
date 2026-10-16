/// 可选地标。发布页与编辑页共用这同一份清单，小程序侧
/// `pages/activity-edit/activity-edit.js` 的 `VENUES` 与它逐字对齐。
///
/// 为什么不放页面里各写一份：改一个坐标要改两处，漏一处的表现是
/// "发布时圈的是国贸、编辑时圈的是三里屯"，而这种错在界面上看不出来。
/// 项目没有地图选点（那要引原生插件），地标是 GEO 经纬度的唯一来源。
class Venue {
  const Venue({
    required this.name,
    required this.address,
    required this.lng,
    required this.lat,
  });

  final String name;
  final String address;
  final double lng;
  final double lat;

  /// 下拉与回显用的全名：`国贸商城 · 朝阳区建国门外大街 1 号`。
  String get fullName => '$name · $address';
}

/// 六个地标。顺序即默认选中项（第一个）。
const List<Venue> kVenues = <Venue>[
  Venue(name: '国贸商城', address: '朝阳区建国门外大街 1 号', lng: 116.4610, lat: 39.9088),
  Venue(name: '三里屯太古里', address: '朝阳区三里屯路 19 号', lng: 116.4550, lat: 39.9330),
  Venue(name: '奥林匹克森林公园', address: '朝阳区科荟路 33 号', lng: 116.3920, lat: 40.0200),
  Venue(name: '五道口购物中心', address: '海淀区成府路 28 号', lng: 116.3370, lat: 39.9930),
  Venue(name: '南锣鼓巷', address: '东城区南锣鼓巷', lng: 116.4040, lat: 39.9370),
  Venue(name: '常营体育公园', address: '朝阳区常营北路', lng: 116.5900, lat: 39.9250),
];

/// 活动地址按 ` venue 名 · 详细地址` 存库，编辑时按前缀拆回地标。
///
/// 返回地标下标与剩下的详细地址；地址不是任何地标开头时返回
/// `(null, 原地址)`——老数据（手工改过的、导入的）不该被静默改成第一个地标。
(int?, String) splitVenue(String address) {
  for (int i = 0; i < kVenues.length; i++) {
    final head = '${kVenues[i].name} · ';
    if (address.startsWith(head)) {
      return (i, address.substring(head.length));
    }
  }
  return (null, address);
}
