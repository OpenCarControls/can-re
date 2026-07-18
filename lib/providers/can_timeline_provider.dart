import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/can_frame.dart';
import '../models/dbc_model.dart';
import '../utils/dbc_decoder.dart';
import 'frame_provider.dart';
import 'dbc_provider.dart';

/// Tracks the timeline state.
class TimelineState {
  // ID -> MuxVal -> List of Frame Indices
  final Map<int, Map<int, List<int>>> index;
  
  TimelineState({required this.index});

  factory TimelineState.empty() => TimelineState(index: {});
}

class TimelineNotifier extends StateNotifier<TimelineState> {
  final Ref ref;

  TimelineNotifier(this.ref) : super(TimelineState.empty()) {
    ref.listen<FrameState>(frameProvider, _onFramesUpdated);
    ref.listen<DbcState>(dbcProvider, _onDbcUpdated);
    
    // Initialize if data already exists
    final frames = ref.read(frameProvider).frames;
    if (frames.isNotEmpty) {
      // Defer to avoid state update during provider initialization
      Future.microtask(() => rebuildIndex());
    }
  }

  void _onDbcUpdated(DbcState? previous, DbcState next) {
    // If DBC changes, we need to completely rebuild the index
    rebuildIndex();
  }

  void _onFramesUpdated(FrameState? previous, FrameState next) {
    final previousLength = previous?.frames.length ?? 0;
    final nextLength = next.frames.length;
    
    if (nextLength < previousLength) {
      // frames were cleared or reduced
      rebuildIndex();
      return;
    }

    if (nextLength > previousLength) {
      // Append new frames to index
      final newFrames = next.frames.skip(previousLength);
      _indexFrames(newFrames, previousLength);
    }
  }

  void rebuildIndex() {
    state = TimelineState.empty();
    final frames = ref.read(frameProvider).frames;
    if (frames.isNotEmpty) {
      _indexFrames(frames, 0);
    }
  }

  void _indexFrames(Iterable<CanFrame> framesToProcess, int startIndex) {
    final activeDbc = ref.read(dbcProvider).activeDbc;
    if (activeDbc == null) return;

    // We mutate a local copy of the index for performance, then update state
    final newIndex = Map<int, Map<int, List<int>>>.from(state.index);

    int currentIndex = startIndex;
    for (final frame in framesToProcess) {
      final message = activeDbc.messages.where((m) => m.id == frame.id).firstOrNull;
      if (message != null) {
        // Find multiplexer signal if any
        DbcSignal? multiplexerSignal;
        for (final sig in message.signals) {
          if (sig.multiplexerIndicator == 'M') {
            multiplexerSignal = sig;
            break;
          }
        }

        int muxValue = 0; // 0 represents non-multiplexed or default
        if (multiplexerSignal != null) {
          try {
            final rawMux = DbcDecoder.extractRawValue(frame.data, multiplexerSignal);
            muxValue = rawMux.toInt();
          } catch (e) {
            // Error extracting mux value, default to 0
          }
        }

        newIndex.putIfAbsent(frame.id, () => {});
        newIndex[frame.id]!.putIfAbsent(muxValue, () => []);
        newIndex[frame.id]![muxValue]!.add(currentIndex);
      }
      currentIndex++;
    }

    state = TimelineState(index: newIndex);
  }
}

final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>((ref) {
  return TimelineNotifier(ref);
});
