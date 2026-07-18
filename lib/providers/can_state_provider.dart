import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/can_frame.dart';
import '../models/dbc_model.dart';
import '../utils/dbc_decoder.dart';
import 'can_timeline_provider.dart';
import 'frame_provider.dart';
import 'dbc_provider.dart';

class DashboardCardModel {
  final DbcMessage message;
  final List<DecodedSignal> signals;
  final int lastUpdateIndex;

  DashboardCardModel({
    required this.message,
    required this.signals,
    required this.lastUpdateIndex,
  });
}

final scrubIndexProvider = StateProvider<int>((ref) => 0);
final isLivePlaybackProvider = StateProvider<bool>((ref) => true);
final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<int>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<Set<int>> {
  FavoritesNotifier() : super({});

  void toggleFavorite(int id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state}..add(id);
    }
  }
}

final dashboardStateProvider = Provider<List<DashboardCardModel>>((ref) {
  final timeline = ref.watch(timelineProvider);
  final frames = ref.watch(frameProvider).frames;
  final activeDbc = ref.watch(dbcProvider).activeDbc;
  final isLive = ref.watch(isLivePlaybackProvider);
  
  if (activeDbc == null || frames.isEmpty) return [];

  int targetIndex = ref.watch(scrubIndexProvider);
  if (isLive) {
    targetIndex = frames.length - 1;
  }
  // Ensure targetIndex is valid
  if (targetIndex >= frames.length) {
    targetIndex = frames.length - 1;
  }

  final cards = <DashboardCardModel>[];
  
  for (final id in timeline.index.keys) {
    final muxMap = timeline.index[id]!;
    
    // We collect the latest frame index for each MuxVal, then we decode them.
    // To deduplicate signals, we will keep track of which frame provided which signal.
    // Actually, simply keeping a Map<String, DecodedSignal> and processing frames in chronological order works perfectly!
    
    final validFrameIndices = <int>[];
    
    for (final muxVal in muxMap.keys) {
      final indices = muxMap[muxVal]!;
      int bsIndex = _binarySearchLE(indices, targetIndex);
      if (bsIndex >= 0) {
        validFrameIndices.add(indices[bsIndex]);
      }
    }
    
    if (validFrameIndices.isEmpty) continue;
    
    // Sort chronologically so that newer frames overwrite older ones in the map
    validFrameIndices.sort();
    
    final signalMap = <String, DecodedSignal>{};
    
    for (final frameIndex in validFrameIndices) {
      final frame = frames[frameIndex];
      final decoded = DbcDecoder.decode(activeDbc, frame);
      if (decoded != null) {
        for (final sig in decoded.decodedSignals) {
          signalMap[sig.signal.name] = sig;
        }
      }
    }
    
    if (signalMap.isNotEmpty) {
      final message = activeDbc.messages.firstWhere((m) => m.id == id);
      final sortedSignals = signalMap.values.toList()
        ..sort((a, b) => a.signal.name.compareTo(b.signal.name));
        
      cards.add(DashboardCardModel(
        message: message,
        signals: sortedSignals,
        lastUpdateIndex: validFrameIndices.last,
      ));
    }
  }
  
  // Sort cards: Favorites first, then by ID
  final favorites = ref.watch(favoritesProvider);
  cards.sort((a, b) {
    final aFav = favorites.contains(a.message.id);
    final bFav = favorites.contains(b.message.id);
    if (aFav && !bFav) return -1;
    if (!aFav && bFav) return 1;
    return a.message.id.compareTo(b.message.id);
  });
  
  return cards;
});

/// Returns the index of the largest element in `list` that is <= `target`.
/// Returns -1 if no such element exists.
int _binarySearchLE(List<int> list, int target) {
  int left = 0;
  int right = list.length - 1;
  int result = -1;

  while (left <= right) {
    int mid = left + ((right - left) >> 1);
    if (list[mid] <= target) {
      result = mid;
      left = mid + 1;
    } else {
      right = mid - 1;
    }
  }
  return result;
}
