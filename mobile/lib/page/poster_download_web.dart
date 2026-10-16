import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// web 实现：把海报 PNG 字节转成 Blob 并触发浏览器下载。
///
/// 这是 web 预览阶段唯一可行的"保存"路径——Flutter web 没有相册概念，存相册要等
/// 装机阶段引入 `image_gallery_saver` 这类原生插件（与"只引纯 Dart 包"的约束冲突，
/// 见 docs/14 未做项）。小程序那边是 `wx.saveImageToPhotosAlbum`，这里用浏览器下载替代。
Future<bool> downloadPng(List<int> bytes, String fileName) {
  try {
    final blob = html.Blob(<Object>[Uint8List.fromList(bytes)], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return Future<bool>.value(true);
  } catch (e) {
    debugPrint('poster download failed: $e');
    return Future<bool>.value(false);
  }
}
