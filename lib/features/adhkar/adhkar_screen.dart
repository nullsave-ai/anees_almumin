import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/adhkar_data.dart';

class AdhkarScreen extends StatelessWidget {
  const AdhkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأذكار')),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            for (final cat in adhkarCategories)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SoftCard(
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => AdhkarDetail(category: cat))),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  child: Row(children: [
                    Icon(cat.icon, color: AppColors.green, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text(cat.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                    const Icon(Icons.chevron_left, color: Colors.black38),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AdhkarDetail extends StatefulWidget {
  const AdhkarDetail({super.key, required this.category});
  final AdhkarCategory category;

  @override
  State<AdhkarDetail> createState() => _AdhkarDetailState();
}

class _AdhkarDetailState extends State<AdhkarDetail> {
  late List<int> _left = [for (final d in widget.category.items) d.count];

  void _tap(int i) {
    if (_left[i] == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _left[i]--);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.category.items;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.title),
        actions: [
          IconButton(
              tooltip: 'إعادة العدادات',
              icon: const Icon(Icons.restart_alt),
              onPressed: () => setState(() => _left = [for (final d in items) d.count])),
        ],
      ),
      body: PageBody(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final d = items[i];
            final done = _left[i] == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: done ? 0.55 : 1,
                child: SoftCard(
                  onTap: () => _tap(i),
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    Text(d.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 21, height: 2, color: AppColors.ink)),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (done)
                        const Icon(Icons.check_circle, color: AppColors.green, size: 22)
                      else
                        Icon(Icons.touch_app_outlined, color: AppColors.green.withAlpha(180), size: 20),
                      const SizedBox(width: 8),
                      Text(done ? 'تم' : 'المتبقي ${ar(_left[i])} من ${ar(d.count)}',
                          style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
