import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/quran_repository.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key, required this.controller});
  final ScrollController controller;

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  late Future<List<Surah>> _future = Deps.quran.surahs();
  final _qc = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _qc.dispose();
    super.dispose();
  }

  Future<void> _open(Surah s) async {
    await Navigator.push(context, smoothRoute(ReaderScreen(surah: s)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: ListenableBuilder(
        listenable: Deps.settings,
        builder: (context, _) =>
            FutureBuilder<List<Surah>>(future: _future, builder: (c, snap) => _content(c, snap, Deps.settings.grid)),
      ),
    );
  }

  Widget _content(BuildContext context, AsyncSnapshot<List<Surah>> snap, bool grid) {
    final p = context.pal;
    final pad = pagePad(context);
    final header = SliverPadding(
      padding: EdgeInsets.fromLTRB(20, pad.top, 20, 0),
      sliver: SliverToBoxAdapter(
        child: Column(children: [
          TabHeader(
            title: 'القرآن الكريم',
            actions: [
              GlassIconButton(
                icon: grid ? AppIcons.list : AppIcons.grid,
                tooltip: grid ? 'عرض قائمة' : 'عرض شبكة',
                onTap: () => Deps.settings.put('grid', !grid),
              ),
            ],
          ),
          GlassBox(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _qc,
              onChanged: (v) => setState(() => _query = normalizeAr(v)),
              decoration: InputDecoration(
                hintText: 'ابحث عن سورة',
                hintStyle: TextStyle(color: p.muted),
                icon: Icon(AppIcons.search, color: p.muted),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ]),
      ),
    );
    final bottom = SliverToBoxAdapter(child: SizedBox(height: pad.bottom));
    Widget scroll(List<Widget> slivers) => CustomScrollView(controller: widget.controller, slivers: slivers);

    if (snap.connectionState != ConnectionState.done) {
      return scroll([
        header,
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (c, i) => const Padding(padding: EdgeInsets.only(bottom: 10), child: Skeleton(height: 66, radius: 24)),
              childCount: 8,
            ),
          ),
        ),
        bottom,
      ]);
    }
    if (snap.hasError) {
      return scroll([
        header,
        SliverToBoxAdapter(
          child: Message(
            icon: AppIcons.wifiOff,
            text: 'تعذر تحميل قائمة السور. تحقق من الاتصال بالإنترنت (مطلوب لأول مرة فقط).',
            actions: [
              FilledButton.icon(
                  onPressed: () => setState(() => _future = Deps.quran.surahs()),
                  icon: Icon(AppIcons.retry),
                  label: const Text('إعادة المحاولة'))
            ],
          ),
        ),
        bottom,
      ]);
    }

    final all = snap.data!;
    final list = _query.isEmpty
        ? all
        : all.where((s) => normalizeAr(s.name).contains(_query) || '${s.number}' == _query || ar(s.number) == _query).toList();
    final lastN = Deps.settings.prefs.getInt('last_surah');
    final last = (_query.isEmpty && lastN != null) ? all.where((e) => e.number == lastN).firstOrNull : null;

    return scroll([
      header,
      if (last != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          sliver: SliverToBoxAdapter(
            child: GlassCard(
              tint: p.green.withAlpha(p.dark ? 55 : 32),
              onTap: () => _open(last),
              child: Row(children: [
                IconBadge(icon: AppIcons.bookmark),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('متابعة القراءة', style: TextStyle(color: p.muted, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(last.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ]),
                ),
                Icon(AppIcons.next, color: p.muted),
              ]),
            ),
          ),
        ),
      if (list.isEmpty)
        SliverToBoxAdapter(child: Message(icon: AppIcons.search, text: 'لا توجد نتائج مطابقة.'))
      else if (grid)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.15),
            delegate: SliverChildBuilderDelegate(
              (c, i) => _SurahTile(s: list[i], grid: true, onTap: () => _open(list[i])),
              childCount: list.length,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (c, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SurahTile(s: list[i], grid: false, onTap: () => _open(list[i])),
              ),
              childCount: list.length,
            ),
          ),
        ),
      bottom,
    ]);
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.s, required this.grid, required this.onTap});
  final Surah s;
  final bool grid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final meta = '${s.meccan ? 'مكية' : 'مدنية'} - ${ar(s.ayahs)} آية';
    final badge = Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: p.green.withAlpha(36)),
      child: Text(ar(s.number), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: p.green)),
    );
    if (grid) {
      return GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: double.infinity,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            badge,
            const SizedBox(height: 10),
            FittedBox(child: Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            const SizedBox(height: 4),
            Text(meta, style: TextStyle(fontSize: 11, color: p.muted)),
          ]),
        ),
      );
    }
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        badge,
        const SizedBox(width: 14),
        Expanded(child: Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
        Text(meta, style: TextStyle(fontSize: 12, color: p.muted)),
      ]),
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

  void _size(double d) => Deps.settings.put('qfont', (Deps.settings.quranFont + d).clamp(18.0, 44.0));

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GlassPage(
      title: widget.surah.name,
      actions: [
        GlassIconButton(icon: AppIcons.zoomOut, tooltip: 'تصغير الخط', size: 40, onTap: () => _size(-2)),
        GlassIconButton(icon: AppIcons.zoomIn, tooltip: 'تكبير الخط', size: 40, onTap: () => _size(2)),
      ],
      child: PageBody(
        child: FutureBuilder<List<Ayah>>(
          future: _future,
          builder: (context, snap) {
            final pad = pagePad(context, nav: false, extraTop: 66);
            if (snap.connectionState != ConnectionState.done) {
              return ListView(padding: pad, children: [
                for (var i = 0; i < 6; i++)
                  const Padding(padding: EdgeInsets.only(bottom: 18), child: Skeleton(height: 26, radius: 8)),
              ]);
            }
            if (snap.hasError) {
              return ListView(padding: pad, children: [
                Message(
                  icon: AppIcons.wifiOff,
                  text: 'تعذر تحميل السورة. تحقق من الاتصال بالإنترنت (مطلوب لأول قراءة فقط).',
                  actions: [
                    FilledButton.icon(
                        onPressed: () => setState(() => _future = Deps.quran.ayahs(widget.surah.number)),
                        icon: Icon(AppIcons.retry),
                        label: const Text('إعادة المحاولة'))
                  ],
                ),
              ]);
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
                  padding: pad,
                  itemCount: ayahs.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${ayahs[i].text} \uFD3F${ar(ayahs[i].number)}\uFD3E',
                      textAlign: TextAlign.justify,
                      style: TextStyle(fontSize: Deps.settings.quranFont, height: 2.1, color: p.ink),
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
