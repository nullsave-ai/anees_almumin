import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/prayer_service.dart';
import '../prayer/prayer_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});
  final void Function(int) onOpenTab;

  @override
  Widget build(BuildContext context) {
    final c = Deps.prayer;
    return SafeArea(
      child: PageBody(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const _DateHeader(),
              const SizedBox(height: 20),
              switch (c.status) {
                LoadState.loading => const Padding(
                    padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
                LoadState.ready => _Ready(c: c),
                _ => SoftCard(
                    child: Message(
                      icon: Icons.location_off_outlined,
                      text: c.error ?? 'تعذر عرض أوقات الصلاة.',
                      actions: [
                        FilledButton.icon(
                            onPressed: () => onOpenTab(1),
                            icon: const Icon(Icons.access_time),
                            label: const Text('أوقات الصلاة')),
                      ],
                    ),
                  ),
              },
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                    child: _Shortcut(
                        icon: Icons.menu_book_outlined,
                        label: 'القرآن الكريم',
                        onTap: () => onOpenTab(2))),
                const SizedBox(width: 12),
                Expanded(
                    child: _Shortcut(
                        icon: Icons.self_improvement_outlined,
                        label: 'الأذكار',
                        onTap: () => onOpenTab(3))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(hijriLabel(now),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink)),
      const SizedBox(height: 4),
      Text(gregorianLabel(now), style: const TextStyle(fontSize: 15, color: Colors.black54)),
    ]);
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.c});
  final PrayerController c;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
              colors: [AppColors.green, AppColors.deep],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الصلاة القادمة', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(prayerNames[c.next]!,
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(fmtTime(c.nextTime!), style: const TextStyle(color: Colors.white, fontSize: 20)),
          ]),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.timer_outlined, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            const Text('المتبقي', style: TextStyle(color: Colors.white70)),
            const Spacer(),
            const CountdownText(
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Row(children: [
          for (final k in PrayerKind.values)
            if (k != PrayerKind.sunrise)
              Expanded(
                child: Column(children: [
                  Icon(prayerIcons[k],
                      size: 20, color: k == c.next ? AppColors.green : Colors.black38),
                  const SizedBox(height: 6),
                  FittedBox(
                      child: Text(prayerNames[k]!,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: k == c.next ? FontWeight.w700 : FontWeight.w400))),
                  const SizedBox(height: 4),
                  FittedBox(
                      child: Text(fmtTime(c.today[k]!),
                          style: TextStyle(
                              fontSize: 12,
                              color: k == c.next ? AppColors.green : Colors.black54))),
                ]),
              ),
        ]),
      ),
    ]);
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(children: [
        Icon(icon, size: 30, color: AppColors.green),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
