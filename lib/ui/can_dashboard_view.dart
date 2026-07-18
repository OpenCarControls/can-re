import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/can_state_provider.dart';
import '../providers/frame_provider.dart';
import '../utils/dbc_decoder.dart';

class CanDashboardView extends ConsumerStatefulWidget {
  const CanDashboardView({super.key});

  @override
  ConsumerState<CanDashboardView> createState() => _CanDashboardViewState();
}

class _CanDashboardViewState extends ConsumerState<CanDashboardView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = ref.watch(frameProvider).frames;
    final allCards = ref.watch(dashboardStateProvider);
    
    final filteredCards = allCards.where((card) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      if (card.message.name.toLowerCase().contains(q)) return true;
      if (card.signals.any((s) => s.signal.name.toLowerCase().contains(q))) return true;
      return false;
    }).toList();

    final favs = ref.watch(favoritesProvider);
    filteredCards.sort((a, b) {
      final aFav = favs.contains(a.message.id);
      final bFav = favs.contains(b.message.id);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return a.message.name.compareTo(b.message.name);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fake AppBar
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search messages or signals...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        // Body
        Expanded(
          child: filteredCards.isEmpty
              ? Center(
                  child: Text(
                    allCards.isEmpty ? 'No parsed CAN data available.\nEnsure a DBC is loaded and data is streaming.' : 'No matches found.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const cardWidth = 320.0;
                    const spacing = 16.0;
                    
                    final availableWidth = constraints.maxWidth - 32.0; // 16px padding on each side
                    int columns = ((availableWidth + spacing) / (cardWidth + spacing)).floor();
                    if (columns < 1) columns = 1;
                    
                    final chunks = <List<DashboardCardModel>>[];
                    for (int i = 0; i < filteredCards.length; i += columns) {
                      int end = i + columns;
                      if (end > filteredCards.length) end = filteredCards.length;
                      chunks.add(filteredCards.sublist(i, end));
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: chunks.length,
                      itemBuilder: (context, index) {
                        final chunk = chunks[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: index == chunks.length - 1 ? 0 : spacing),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < columns; i++)
                                if (i < chunk.length)
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(right: i == columns - 1 ? 0 : spacing),
                                      child: _DashboardCard(
                                        key: ValueKey(chunk[i].message.id),
                                        model: chunk[i],
                                      ),
                                    ),
                                  )
                                else
                                  const Expanded(child: SizedBox.shrink()),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        // Scrubber
        if (frames.isNotEmpty) const _TimelineScrubber(),
      ],
    );
  }
}

class _DashboardCard extends ConsumerWidget {
  final DashboardCardModel model;

  const _DashboardCard({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFav = ref.watch(favoritesProvider).contains(model.message.id);
    
    // Calculate how old this data is based on the frame index gap
    final currentScrubIndex = ref.watch(scrubIndexProvider);
    final frames = ref.watch(frameProvider).frames;
    final isLive = ref.watch(isLivePlaybackProvider);
    final targetIndex = isLive ? frames.length - 1 : currentScrubIndex;
    
    final framesAgo = targetIndex - model.lastUpdateIndex;
    final lastFrame = frames[model.lastUpdateIndex];

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.message.name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '0x${model.message.id.toRadixString(16).toUpperCase()}',
                              style: GoogleFonts.robotoMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            framesAgo == 0 ? 'Just now' : '$framesAgo frames ago',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    color: isFav ? Colors.amber : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    ref.read(favoritesProvider.notifier).toggleFavorite(model.message.id);
                  },
                ),
              ],
            ),
          ),
          
          // Signals List
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: model.signals.map((sig) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          sig.signal.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sig.formattedValue,
                        style: GoogleFonts.robotoMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Footer / Meta
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Last TS: ${lastFrame.formattedTimestamp}',
              style: GoogleFonts.inter(fontSize: 10, color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineScrubber extends ConsumerWidget {
  const _TimelineScrubber();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frames = ref.watch(frameProvider).frames;
    final currentIndex = ref.watch(scrubIndexProvider);
    final isLive = ref.watch(isLivePlaybackProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (frames.isEmpty) return const SizedBox.shrink();

    final maxIndex = frames.length - 1;
    final sliderValue = (isLive ? maxIndex : currentIndex).clamp(0, maxIndex).toDouble();

    return Container(
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SafeArea(
        child: Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () {
                ref.read(isLivePlaybackProvider.notifier).state = true;
              },
              icon: Icon(isLive ? Icons.play_arrow : Icons.pause, size: 18),
              label: Text(isLive ? 'Live' : 'Paused'),
              style: FilledButton.styleFrom(
                backgroundColor: isLive ? colorScheme.primaryContainer : colorScheme.surface,
                foregroundColor: isLive ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: sliderValue,
                  min: 0,
                  max: maxIndex.toDouble(),
                  onChanged: (val) {
                    ref.read(isLivePlaybackProvider.notifier).state = false;
                    ref.read(scrubIndexProvider.notifier).state = val.toInt();
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 80,
              child: Text(
                '${sliderValue.toInt()} / $maxIndex',
                style: GoogleFonts.robotoMono(fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
