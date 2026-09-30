import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/cities.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('أوقات الصلاة'),
        actions: [
          IconButton(
              tooltip: 'الإعدادات',
              icon: const Icon(Icons.tune),
              onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const _SettingsSheet())),
        ],
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            switch (c.status) {
              case LoadState.loading:
                return const Center(child: CircularProgressIndicator());
              case LoadState.ready:
                return _list(c);
              default:
                return Message(
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
                );
            }
          },
        ),
      ),
    );
  }

  Widget _list(PrayerController c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(children: [
          const Icon(Icons.place_outlined, size: 18, color: AppColors.green),
          const SizedBox(width: 6),
          Text(Deps.settings.place, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(hijriLabel(DateTime.now()), style: const TextStyle(color: Colors.black54)),
        ]),
        const SizedBox(height: 14),
        SoftCard(
          color: AppColors.green.withAlpha(20),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('الصلاة القادمة', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text(prayerNames[c.next]!,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('المتبقي', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              const CountdownText(
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.green)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        for (final k in PrayerKind.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              color: k == c.next ? AppColors.green.withAlpha(24) : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(prayerIcons[k], color: AppColors.green),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(prayerNames[k]!,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: k == c.next ? FontWeight.w700 : FontWeight.w500))),
                Text(fmtTime(c.today[k]!),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ],
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
      builder: (context, _) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
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
              leading: const Icon(Icons.battery_saver_outlined),
              title: const Text('السماح بالعمل في الخلفية'),
              subtitle: const Text('يضمن وصول الإشعارات في وقتها عند إغلاق التطبيق'),
              onTap: () => Permission.ignoreBatteryOptimizations.request(),
            ),
          ],
        ),
      ),
    );
  }
}
