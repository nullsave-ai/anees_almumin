import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/cities.dart';
import '../../services/adhan_service.dart';
import '../../services/prayer_service.dart';
import 'prayer_controller.dart';

Future<void> chooseCity(BuildContext context) async {
  final key = await pickOne(context, 'اختر المدينة',
      {for (var i = 0; i < cities.length; i++) '$i': cities[i].name}, null);
  if (key == null) return;
  final c = cities[int.parse(key)];
  await Deps.settings.setLocation(c.lat, c.lng, c.tz, c.name, auto: false);
}

class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Deps.prayer;
    return PageBody(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          child: ListView(
            key: ValueKey(c.status),
            padding: pagePad(context),
            children: [
              TabHeader(
                title: 'أوقات الصلاة',
                subtitle: c.status == LoadState.ready ? Deps.settings.place : null,
                actions: [
                  GlassIconButton(
                    icon: Icons.tune,
                    tooltip: 'الإعدادات',
                    onTap: () => showGlassSheet(context, builder: (_) => const _SettingsSheet()),
                  ),
                ],
              ),
              ..._body(context, c),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, PrayerController c) {
    switch (c.status) {
      case LoadState.loading:
        return const [Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()))];
      case LoadState.ready:
        const kinds = PrayerKind.values;
        return [
          Reveal(index: 0, child: _SunCard(c: c)),
          const SizedBox(height: 24),
          for (var i = 0; i < kinds.length; i++)
            Reveal(
              index: i + 1,
              child: _TimelineItem(kind: kinds[i], c: c, first: i == 0, last: i == kinds.length - 1),
            ),
        ];
      default:
        return [
          Message(
            icon: c.status == LoadState.error ? Icons.error_outline : Icons.location_off_outlined,
            text: c.error ?? 'حدد موقعك لعرض أوقات الصلاة.',
            actions: [
              FilledButton.icon(
                  onPressed: () {
                    Deps.settings.put('auto', true);
                    c.refresh(relocate: true);
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text('تحديد الموقع تلقائيًا')),
              OutlinedButton.icon(
                  onPressed: () => chooseCity(context),
                  icon: const Icon(Icons.location_city),
                  label: const Text('اختيار المدينة')),
            ],
          ),
        ];
    }
  }
}

/// بطاقة عائمة: الصلاة القادمة + قوس مسار الشمس من الشروق إلى الغروب.
class _SunCard extends StatelessWidget {
  const _SunCard({required this.c});
  final PrayerController c;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final sunrise = c.today[PrayerKind.sunrise]!;
    final sunset = c.today[PrayerKind.maghrib]!;
    return Floating(
      amplitude: 3,
      period: 4200,
      child: GlassCard(
        radius: 34,
        blur: 20,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الصلاة القادمة', style: TextStyle(color: p.muted)),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  transitionBuilder: (w, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, .3), end: Offset.zero).animate(a), child: w),
                  ),
                  child: Text(prayerNames[c.next]!,
                      key: ValueKey(c.next), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('المتبقي', style: TextStyle(color: p.muted)),
              const SizedBox(height: 4),
              CountdownText(style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.green)),
            ]),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 118,
            child: ValueListenableBuilder<Duration>(
              valueListenable: c.remaining,
              builder: (_, __, ___) {
                final now = DateTime.now().millisecondsSinceEpoch;
                final a = sunrise.millisecondsSinceEpoch, b = sunset.millisecondsSinceEpoch;
                final t = b <= a ? 0.0 : ((now - a) / (b - a)).clamp(0.0, 1.0);
                final day = now >= a && now <= b;
                return CustomPaint(
                  size: Size.infinite,
                  painter: _ArcPainter(t, day, p.green, p.gold, p.muted.withAlpha(60)),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(day ? 'النهار' : 'الليل', style: TextStyle(fontSize: 12, color: p.muted)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _SunLabel(icon: Icons.wb_twilight, label: 'الشروق', time: sunrise),
            _SunLabel(icon: Icons.nights_stay_outlined, label: 'الغروب', time: sunset),
          ]),
        ]),
      ),
    );
  }
}

class _SunLabel extends StatelessWidget {
  const _SunLabel({required this.icon, required this.label, required this.time});
  final IconData icon;
  final String label;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(children: [
      Icon(icon, size: 20, color: p.gold),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: p.muted)),
        Text(fmtTime(time), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    ]);
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.t, this.day, this.green, this.gold, this.track);
  final double t;
  final bool day;
  final Color green, gold, track;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rx = w / 2 - 16, ry = h - 22;
    final c = Offset(w / 2, h - 6);
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, math.pi, math.pi, false, base);
    canvas.drawLine(Offset(4, c.dy), Offset(w - 4, c.dy), Paint()..color = track..strokeWidth = 1);
    // الشروق على اليمين (اتجاه RTL) والتقدم يسير نحو اليسار
    final prog = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: [gold, green]).createShader(rect);
    if (t > 0) canvas.drawArc(rect, 2 * math.pi, -math.pi * t, false, prog);
    final a = 2 * math.pi - math.pi * t;
    final pos = Offset(c.dx + rx * math.cos(a), c.dy + ry * math.sin(a));
    if (day) {
      canvas.drawCircle(pos, 20, Paint()..color = gold.withAlpha(70)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    canvas.drawCircle(pos, 9, Paint()..color = day ? gold : track);
    canvas.drawCircle(pos, 9, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white.withAlpha(day ? 200 : 60));
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.t != t || o.day != day;
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.kind, required this.c, required this.first, required this.last});
  final PrayerKind kind;
  final PrayerController c;
  final bool first, last;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final isNext = c.isNextKind(kind);
    final passed = c.isPassed(kind);
    final filled = passed || isNext;
    final line = p.green.withAlpha(passed ? 140 : 50);
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      width: isNext ? 22 : 16,
      height: isNext ? 22 : 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? p.green : p.bg,
        border: Border.all(color: filled ? p.green : p.muted.withAlpha(120), width: 2),
        boxShadow: isNext ? [BoxShadow(color: p.green.withAlpha(130), blurRadius: 14, spreadRadius: 2)] : null,
      ),
      child: passed ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
    );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 30,
          child: Column(children: [
            Expanded(child: Center(child: Container(width: 2, color: first ? Colors.transparent : line))),
            dot,
            Expanded(child: Center(child: Container(width: 2, color: last ? Colors.transparent : line))),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 12),
            child: isNext ? _NextCard(kind: kind, c: c) : _PlainCard(kind: kind, c: c, passed: passed),
          ),
        ),
      ]),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.kind, required this.c});
  final PrayerKind kind;
  final PrayerController c;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Floating(
      amplitude: 3,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: p.dark ? const [Color(0xFF1E7A64), Color(0xFF0F3E34)] : const [Color(0xFF1F6F5C), Color(0xFF14483C)],
          ),
          boxShadow: [BoxShadow(color: p.green.withAlpha(p.dark ? 80 : 120), blurRadius: 28, offset: const Offset(0, 14))],
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(34)),
            child: Icon(prayerIcons[kind], color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prayerNames[kind]!,
                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.timer_outlined, size: 16, color: p.gold),
                const SizedBox(width: 5),
                const CountdownText(style: TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
            ]),
          ),
          Text(fmtTime(c.today[kind]!),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _PlainCard extends StatelessWidget {
  const _PlainCard({required this.kind, required this.c, required this.passed});
  final PrayerKind kind;
  final PrayerController c;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final isSun = kind == PrayerKind.sunrise;
    return AnimatedOpacity(
      opacity: passed ? .6 : 1,
      duration: const Duration(milliseconds: 400),
      child: GlassCard(
        radius: 26,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSun ? 12 : 16),
        child: Row(children: [
          IconBadge(icon: prayerIcons[kind]!, size: 44, color: isSun ? p.gold : p.green),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prayerNames[kind]!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              if (isSun) Text('نهاية وقت الفجر', style: TextStyle(fontSize: 12, color: p.muted)),
            ]),
          ),
          Text(fmtTime(c.today[kind]!), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final s = Deps.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('إعدادات الصلاة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.my_location),
            title: const Text('تحديد الموقع تلقائيًا'),
            value: s.auto,
            onChanged: (v) async {
              await s.put('auto', v);
              if (v) Deps.prayer.refresh(relocate: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_city),
            title: const Text('اختيار المدينة يدويًا'),
            subtitle: Text(s.place.isEmpty ? 'غير محددة' : s.place),
            onTap: () => chooseCity(context),
          ),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('طريقة الحساب'),
            subtitle: Text(calcMethods[s.method] ?? ''),
            onTap: () async {
              final v = await pickOne(context, 'طريقة الحساب', calcMethods, s.method);
              if (v != null) s.put('method', v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('المذهب (وقت العصر)'),
            subtitle: Text(madhabs[s.madhab] ?? ''),
            onTap: () async {
              final v = await pickOne(context, 'المذهب', madhabs, s.madhab);
              if (v != null) s.put('madhab', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('إشعارات الصلاة'),
            value: s.notify,
            onChanged: (v) async {
              if (v) await Deps.notifications.requestPermissions();
              await s.put('notify', v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('المؤذن وصوت الأذان'),
            subtitle: Text(Deps.adhan.nameOf(s.voice)),
            onTap: () => showGlassSheet(context, builder: (_) => const VoiceSheet()),
          ),
          ListTile(
            leading: const Icon(Icons.battery_saver_outlined),
            title: const Text('السماح بالعمل في الخلفية'),
            subtitle: const Text('يضمن وصول الإشعارات في وقتها عند إغلاق التطبيق'),
            onTap: () => Permission.ignoreBatteryOptimizations.request(),
          ),
        ]),
      ),
    );
  }
}

class VoiceSheet extends StatefulWidget {
  const VoiceSheet({super.key});

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> {
  String? _playing;
  late final _sub = Deps.adhan.onComplete.listen((_) {
    if (mounted) setState(() => _playing = null);
  });

  @override
  void initState() {
    super.initState();
    _sub;
  }

  @override
  void dispose() {
    _sub.cancel();
    Deps.adhan.stop();
    super.dispose();
  }

  Future<void> _toggle(AdhanVoice v) async {
    if (_playing == v.id) {
      await Deps.adhan.stop();
      setState(() => _playing = null);
    } else {
      setState(() => _playing = v.id);
      try {
        await Deps.adhan.preview(v);
      } catch (_) {
        if (mounted) setState(() => _playing = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return FutureBuilder<List<AdhanVoice>>(
      future: Deps.adhan.voices(),
      builder: (context, snap) {
        final voices = snap.data ?? const <AdhanVoice>[];
        return ListenableBuilder(
          listenable: Deps.settings,
          builder: (context, _) {
            final cur = Deps.settings.voice;
            Widget tile(String id, String name, AdhanVoice? v) => ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Icon(cur == id ? Icons.check_circle : Icons.radio_button_unchecked,
                        key: ValueKey(cur == id), color: cur == id ? p.green : p.muted),
                  ),
                  title: Text(name, style: const TextStyle(fontSize: 16)),
                  trailing: v == null
                      ? null
                      : GlassIconButton(
                          size: 40,
                          icon: _playing == id ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          tooltip: 'معاينة',
                          onTap: () => _toggle(v)),
                  onTap: () => Deps.settings.put('voice', id),
                );
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Text('المؤذن وصوت الأذان', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                tile('', 'صوت الإشعار الافتراضي', null),
                for (final v in voices) tile(v.id, v.name, v),
                if (snap.connectionState == ConnectionState.done && voices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'لم تُضف أصوات أذان بعد. ضع ملفات mp3 داخل assets/adhan ثم شغّل sync_adhan.sh وأعد بناء التطبيق.',
                      style: TextStyle(color: p.muted, height: 1.7),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
