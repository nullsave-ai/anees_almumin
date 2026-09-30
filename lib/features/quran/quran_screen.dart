import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/quran_repository.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  late Future<List<Surah>> _future = Deps.quran.surahs();
  String _query = '';

  Future<void> _open(Surah s) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(surah: s)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('القرآن الكريم')),
      body: PageBody(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = normalizeAr(v)),
              decoration: InputDecoration(
                hintText: 'ابحث عن سورة',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Surah>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Message(
                    icon: Icons.wifi_off,
                    text: 'تعذر تحميل قائمة السور. تحقق من الاتصال بالإنترنت (مطلوب لأول مرة فقط).',
                    actions: [
                      FilledButton.icon(
                          onPressed: () => setState(() => _future = Deps.quran.surahs()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'))
                    ],
                  );
                }
                final all = snap.data!;
                final list = _query.isEmpty
                    ? all
                    : all
                        .where((s) =>
                            normalizeAr(s.name).contains(_query) || ar(s.number) == _query || '${s.number}' == _query)
                        .toList();
                if (list.isEmpty) {
                  return const Message(icon: Icons.search_off, text: 'لا توجد نتائج مطابقة.');
                }
                final p = Deps.settings.prefs;
                final lastN = p.getInt('last_surah');
                final showLast = _query.isEmpty && lastN != null;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: list.length + (showLast ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (showLast && i == 0) {
                      final s = all.firstWhere((e) => e.number == lastN);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SoftCard(
                          color: AppColors.green.withAlpha(24),
                          onTap: () => _open(s),
                          child: Row(children: [
                            const Icon(Icons.bookmark_outline, color: AppColors.green),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('متابعة القراءة', style: TextStyle(color: Colors.black54)),
                              const SizedBox(height: 2),
                              Text(s.name,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                            ])),
                            const Icon(Icons.chevron_left),
                          ]),
                        ),
                      );
                    }
                    final s = list[i - (showLast ? 1 : 0)];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        onTap: () => _open(s),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: AppColors.green.withAlpha(24), shape: BoxShape.circle),
                            child: Text(ar(s.number),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.green,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Text(s.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
                          Text('${s.meccan ? 'مكية' : 'مدنية'} - ${ar(s.ayahs)} آية',
                              style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.surah});
  final Surah surah;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<List<Ayah>> _future = Deps.quran.ayahs(widget.surah.number);
  late final ScrollController _sc;

  @override
  void initState() {
    super.initState();
    final p = Deps.settings.prefs;
    final same = p.getInt('last_surah') == widget.surah.number;
    _sc = ScrollController(initialScrollOffset: same ? (p.getDouble('last_offset') ?? 0) : 0);
    p.setInt('last_surah', widget.surah.number);
    if (!same) p.setDouble('last_offset', 0);
  }

  void _save() {
    if (!_sc.hasClients) return;
    final p = Deps.settings.prefs;
    p.setInt('last_surah', widget.surah.number);
    p.setDouble('last_offset', _sc.offset);
  }

  @override
  void dispose() {
    _save();
    _sc.dispose();
    super.dispose();
  }

  void _size(double delta) {
    final v = (Deps.settings.quranFont + delta).clamp(18.0, 44.0);
    Deps.settings.put('qfont', v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surah.name),
        actions: [
          IconButton(
              tooltip: 'تصغير الخط',
              icon: const Icon(Icons.text_decrease),
              onPressed: () => _size(-2)),
          IconButton(
              tooltip: 'تكبير الخط',
              icon: const Icon(Icons.text_increase),
              onPressed: () => _size(2)),
        ],
      ),
      body: PageBody(
        child: FutureBuilder<List<Ayah>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Message(
                icon: Icons.wifi_off,
                text: 'تعذر تحميل السورة. تحقق من الاتصال بالإنترنت (مطلوب لأول قراءة فقط).',
                actions: [
                  FilledButton.icon(
                      onPressed: () =>
                          setState(() => _future = Deps.quran.ayahs(widget.surah.number)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'))
                ],
              );
            }
            final ayahs = snap.data!;
            return NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                _save();
                return false;
              },
              child: ListenableBuilder(
                listenable: Deps.settings,
                builder: (context, _) => ListView.builder(
                  controller: _sc,
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                  itemCount: ayahs.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${ayahs[i].text} \uFD3F${ar(ayahs[i].number)}\uFD3E',
                      textAlign: TextAlign.justify,
                      style: TextStyle(
                          fontSize: Deps.settings.quranFont, height: 2.1, color: AppColors.ink),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
