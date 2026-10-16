/// 把海报 PNG 字节存到本机。默认（非 web）实现：没有原生插件时做不到写相册，
/// 返回 false 让调用方退回到"弹出图片预览"。见 `poster_download_web.dart`。
Future<bool> downloadPng(List<int> bytes, String fileName) => Future<bool>.value(false);
