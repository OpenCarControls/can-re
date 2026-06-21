import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/can_frame.dart';

/// The state class holds the raw list of frames and any active filters.
class FrameState {
  final List<CanFrame> frames;
  final String filterBus;
  final String filterIdHex;
  final bool isLoading;
  final Map<String, bool> visibleColumns;

  FrameState({
    this.frames = const [],
    this.filterBus = '',
    this.filterIdHex = '',
    this.isLoading = false,
    this.visibleColumns = const {
      'Timestamp': true,
      'ID': true,
      'Ext': true,
      'Dir': true,
      'Bus': true,
      'Len': true,
      'Data': true,
    },
  });

  FrameState copyWith({
    List<CanFrame>? frames,
    String? filterBus,
    String? filterIdHex,
    bool? isLoading,
    Map<String, bool>? visibleColumns,
  }) {
    return FrameState(
      frames: frames ?? this.frames,
      filterBus: filterBus ?? this.filterBus,
      filterIdHex: filterIdHex ?? this.filterIdHex,
      isLoading: isLoading ?? this.isLoading,
      visibleColumns: visibleColumns ?? this.visibleColumns,
    );
  }

  /// Returns the filtered list of frames.
  List<CanFrame> get filteredFrames {
    return frames.where((frame) {
      if (filterBus.isNotEmpty && frame.bus.toString() != filterBus) {
        return false;
      }
      if (filterIdHex.isNotEmpty) {
        final fId = filterIdHex.toLowerCase();
        if (!frame.idHex.toLowerCase().contains(fId)) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}

class FrameNotifier extends Notifier<FrameState> {
  @override
  FrameState build() {
    return FrameState();
  }

  void addFrame(CanFrame frame) {
    state = state.copyWith(frames: [...state.frames, frame]);
  }

  void addFrames(List<CanFrame> newFrames) {
    state = state.copyWith(frames: [...state.frames, ...newFrames]);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void clearFrames() {
    state = FrameState(
      filterBus: state.filterBus,
      filterIdHex: state.filterIdHex,
      isLoading: state.isLoading,
      visibleColumns: state.visibleColumns,
    );
  }

  void setFilterBus(String? bus) {
    state = state.copyWith(filterBus: bus ?? '');
  }

  void setFilterIdHex(String? idHex) {
    state = state.copyWith(filterIdHex: idHex ?? '');
  }

  void toggleColumn(String column) {
    final updated = Map<String, bool>.from(state.visibleColumns);
    updated[column] = !(updated[column] ?? true);
    state = state.copyWith(visibleColumns: updated);
  }
}

final frameProvider = NotifierProvider<FrameNotifier, FrameState>(() {
  return FrameNotifier();
});
