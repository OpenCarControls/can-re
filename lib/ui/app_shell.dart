import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import '../models/dbc_model.dart';
import '../providers/dbc_provider.dart';
import '../providers/frame_provider.dart';
import '../providers/connection_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {

  Future<bool> _promptUnsavedChanges() async {
    final state = ref.read(dbcProvider);
    if (!state.hasUnsavedChanges) return true;
    if (state.activeDbc != null && state.activeDbc!.messages.isEmpty && state.activeDbc!.unparsedLines.isEmpty) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes in your active DBC. Are you sure you want to discard them?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _loadDbc() async {
    if (!await _promptUnsavedChanges()) return;

    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['dbc'],
    );

    if (result != null) {
      try {
        String content = '';
        if (kIsWeb) {
          content = String.fromCharCodes(result.files.single.bytes!);
        } else if (result.files.single.path != null) {
          final file = File(result.files.single.path!);
          content = await file.readAsString();
        }
        
        if (content.isNotEmpty) {
          final dbc = Dbc.parse(content);
          ref.read(dbcProvider.notifier).addDbc(dbc);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('DBC loaded successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading DBC: $e')),
          );
        }
      }
    }
  }

  Future<void> _unloadDbc() async {
    if (!await _promptUnsavedChanges()) return;

    ref.read(dbcProvider.notifier).clearActiveDbc();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DBC unloaded')),
      );
    }
  }

  Widget _buildDbcComboButton(BuildContext context, DbcState dbcState) {
    final hasDbc = dbcState.activeDbc != null;
    final hasUnsaved = dbcState.hasUnsavedChanges;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: hasUnsaved ? colorScheme.tertiaryContainer : colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: hasDbc ? _unloadDbc : _loadDbc,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Badge(
                    isLabelVisible: hasDbc && hasUnsaved,
                    child: Icon(hasDbc ? Icons.close : Icons.folder_open, 
                      size: 18, 
                      color: hasUnsaved ? colorScheme.onTertiaryContainer : colorScheme.onSecondaryContainer
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasDbc ? 'Unload DBC${hasUnsaved ? '*' : ''}' : 'Load DBC',
                    style: TextStyle(
                      color: hasUnsaved ? colorScheme.onTertiaryContainer : colorScheme.onSecondaryContainer, 
                      fontWeight: FontWeight.w500
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 24, color: (hasUnsaved ? colorScheme.onTertiaryContainer : colorScheme.onSecondaryContainer).withValues(alpha: 0.2)),
          Tooltip(
            message: hasDbc ? 'Edit loaded DBC' : 'Create new DBC',
            child: InkWell(
              onTap: () {
                if (!hasDbc) {
                  ref.read(dbcProvider.notifier).addDbc(Dbc());
                }
                context.push('/dbc_editor');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Icon(
                  hasDbc ? Icons.edit : Icons.add,
                  size: 18,
                  color: hasUnsaved ? colorScheme.onTertiaryContainer : colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDesktop) {
    final frameState = ref.watch(frameProvider);
    final connNotifier = ref.read(connectionProvider.notifier);
    
    return AppBar(
      title: Text(
        'OpenCarControls CAN RE',
        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
      ),
      scrolledUnderElevation: 0.0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: [
        if (frameState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        
        // Context Actions
        if (isDesktop) ...[
          TextButton.icon(
            onPressed: frameState.isLoading ? null : () => connNotifier.loadCsv(),
            icon: const Icon(Icons.folder_open),
            label: const Text('Load CSV'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: frameState.frames.isEmpty ? null : () => connNotifier.saveCsv(),
            icon: const Icon(Icons.save),
            label: const Text('Save CSV'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => connNotifier.connectLive(),
            icon: const Icon(Icons.bolt),
            label: const Text('Connect Live'),
          ),
          const SizedBox(width: 8),
          _buildDbcComboButton(context, ref.watch(dbcProvider)),
          const SizedBox(width: 16),
        ] else ...[
          // Mobile overflow menu
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'load') connNotifier.loadCsv();
              if (value == 'save') connNotifier.saveCsv();
              if (value == 'live') connNotifier.connectLive();
              if (value == 'dbc') context.push('/dbc_editor');
              if (value == 'load_dbc') _loadDbc();
              if (value == 'unload_dbc') _unloadDbc();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'load', child: Text('Load CSV')),
              const PopupMenuItem(value: 'save', child: Text('Save CSV')),
              const PopupMenuItem(value: 'live', child: Text('Connect Live')),
              const PopupMenuItem(value: 'dbc', child: Text('DBC Editor')),
              const PopupMenuItem(value: 'load_dbc', child: Text('Load DBC')),
              const PopupMenuItem(value: 'unload_dbc', child: Text('Unload DBC')),
            ],
          ),
          const SizedBox(width: 4),
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        return Scaffold(
          appBar: _buildAppBar(isDesktop),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDesktop)
                NavigationRail(
                  selectedIndex: widget.navigationShell.currentIndex,
                  onDestinationSelected: (index) {
                    widget.navigationShell.goBranch(
                      index,
                      initialLocation: index == widget.navigationShell.currentIndex,
                    );
                  },
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.list),
                      selectedIcon: Icon(Icons.list_alt),
                      label: Text('Trace'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('State'),
                    ),
                  ],
                ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: widget.navigationShell,
              ),
            ],
          ),
          bottomNavigationBar: isDesktop ? null : NavigationBar(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: (index) {
              widget.navigationShell.goBranch(
                index,
                initialLocation: index == widget.navigationShell.currentIndex,
              );
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.list),
                selectedIcon: Icon(Icons.list_alt),
                label: 'Trace',
              ),
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'State',
              ),
            ],
          ),
        );
      },
    );
  }
}
