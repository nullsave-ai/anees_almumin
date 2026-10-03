import 'package:flutter/services.dart';

/// جسر إلى كود أندرويد الأصلي: تعيين الخلفية الثابتة، الخلفية الحية، وويدجت الصلاة.
class WallpaperService {
  static const _ch = MethodChannel('anees/wallpaper');

  /// [which]: 1 الشاشة الرئيسية، 2 شاشة القفل، 3 كلتاهما.
  Future<void> setStatic(String path, int which) => _ch.invokeMethod('setStatic', {'path': path, 'which': which});

  /// يفتح معاينة النظام للخلفية الحية ليؤكد المستخدم التعيين.
  Future<void> setLive() => _ch.invokeMethod('setLive');

  Future<bool> pinWidget() async => (await _ch.invokeMethod<bool>('pinWidget')) ?? false;

  Future<void> refreshWidget() async {
    try {
      await _ch.invokeMethod('refreshWidget');
    } catch (_) {}
  }
}
