import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dbc_model.dart';

class DbcState {
  final List<Dbc> dbcs;
  final Dbc? activeDbc;
  final bool hasUnsavedChanges;

  DbcState({
    this.dbcs = const [],
    this.activeDbc,
    this.hasUnsavedChanges = false,
  });

  DbcState copyWith({
    List<Dbc>? dbcs,
    Dbc? activeDbc,
    bool? hasUnsavedChanges,
  }) {
    return DbcState(
      dbcs: dbcs ?? this.dbcs,
      activeDbc: activeDbc ?? this.activeDbc,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }
}

class DbcNotifier extends StateNotifier<DbcState> {
  DbcNotifier() : super(DbcState()) {
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString('dbc_draft');
      if (draftStr != null && draftStr.isNotEmpty) {
        final dbc = Dbc.parse(draftStr);
        state = state.copyWith(
          dbcs: [dbc],
          activeDbc: dbc,
          hasUnsavedChanges: true,
        );
      }
    } catch (e) {
      debugPrint('Failed to load DBC draft: $e');
    }
  }

  Future<void> _saveDraft() async {
    if (state.activeDbc == null || !state.hasUnsavedChanges) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dbc_draft', state.activeDbc!.toDbcString());
    } catch (e) {
      debugPrint('Failed to save DBC draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('dbc_draft');
    } catch (e) {
      debugPrint('Failed to clear DBC draft: $e');
    }
  }

  void addDbc(Dbc dbc) {
    state = state.copyWith(
      dbcs: [...state.dbcs, dbc],
      activeDbc: dbc, // Set the newly added DBC as active
      hasUnsavedChanges: false,
    );
  }

  void setActiveDbc(Dbc dbc) {
    state = state.copyWith(activeDbc: dbc);
  }

  void updateActiveDbc(Dbc updatedDbc) {
    if (state.activeDbc == null) return;
    
    final index = state.dbcs.indexOf(state.activeDbc!);
    if (index != -1) {
      final newDbcs = List<Dbc>.from(state.dbcs);
      newDbcs[index] = updatedDbc;
      state = state.copyWith(
        dbcs: newDbcs,
        activeDbc: updatedDbc,
        hasUnsavedChanges: true,
      );
      _saveDraft();
    }
  }

  void clearActiveDbc() {
    if (state.activeDbc == null) return;
    final newDbcs = List<Dbc>.from(state.dbcs)..remove(state.activeDbc);
    state = DbcState(
      dbcs: newDbcs,
      activeDbc: newDbcs.isNotEmpty ? newDbcs.last : null,
      hasUnsavedChanges: false,
    );
    _clearDraft();
  }

  void markAsSaved() {
    state = state.copyWith(hasUnsavedChanges: false);
    _clearDraft();
  }

  void clearAll() {
    state = DbcState();
    _clearDraft();
  }
}

final dbcProvider = StateNotifierProvider<DbcNotifier, DbcState>((ref) {
  return DbcNotifier();
});
