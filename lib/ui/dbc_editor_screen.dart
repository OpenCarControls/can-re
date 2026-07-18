import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../models/dbc_model.dart';
import '../providers/dbc_provider.dart';
import 'widgets/can_matrix_visualizer.dart';
import 'widgets/signal_editor_form.dart';

// Import JS interop for web file saving if needed, but for now we fallback to standard download.
// See `saveDbcWeb` helper.

class DbcEditorScreen extends ConsumerStatefulWidget {
  const DbcEditorScreen({super.key});

  @override
  ConsumerState<DbcEditorScreen> createState() => _DbcEditorScreenState();
}

class _DbcEditorScreenState extends ConsumerState<DbcEditorScreen> {
  DbcMessage? _selectedMessage;
  DbcSignal? _selectedSignal;

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
      withData: true,
    );

    if (result != null) {
      String content;
      if (kIsWeb) {
        content = utf8.decode(result.files.single.bytes!);
      } else {
        final path = result.files.single.path;
        if (path != null) {
          content = await File(path).readAsString();
        } else {
          content = utf8.decode(result.files.single.bytes!);
        }
      }

      try {
        final dbc = Dbc.parse(content);
        ref.read(dbcProvider.notifier).addDbc(dbc);
        setState(() {
          _selectedMessage = null;
          _selectedSignal = null;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error parsing DBC: $e')));
        }
      }
    }
  }

  Future<void> _saveDbc() async {
    final activeDbc = ref.read(dbcProvider).activeDbc;
    if (activeDbc == null) return;

    final content = activeDbc.toDbcString();

    if (kIsWeb) {
      // Basic fallback for web: triggers a download
      // For true PWA Draw.io style we need the File System Access API (showSaveFilePicker).
      // That requires JS interop setup. We'll use a simple fallback first.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web save triggers download. Native File System Access API pending.')),
      );
      // Basic download using an anchor tag (omitted here for simplicity, requires dart:html/web)
      // Usually handled by a helper package like `file_saver`.
    } else {
      String? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Save DBC',
        fileName: 'network.dbc',
        type: FileType.custom,
        allowedExtensions: ['dbc'],
      );

      if (outputFile != null) {
        if (!outputFile.toLowerCase().endsWith('.dbc')) {
          outputFile += '.dbc';
        }
        await File(outputFile).writeAsString(content);
        ref.read(dbcProvider.notifier).markAsSaved();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $outputFile')));
        }
      }
    }
  }

  void _addMessage() {
    final activeDbc = ref.read(dbcProvider).activeDbc;
    if (activeDbc == null) return;

    setState(() {
      final newMsg = DbcMessage(
        id: 0x100 + activeDbc.messages.length,
        name: 'New_Message_${activeDbc.messages.length}',
        length: 8,
        transmitter: 'Vector__XXX',
        signals: [],
      );
      activeDbc.messages.add(newMsg);
      ref.read(dbcProvider.notifier).updateActiveDbc(activeDbc);
      _selectedMessage = newMsg;
      _selectedSignal = null;
    });
  }

  void _addSignal() {
    if (_selectedMessage == null) return;
    
    setState(() {
      final newSig = DbcSignal(
        name: 'New_Signal_${_selectedMessage!.signals.length}',
        startBit: 0,
        length: 8,
        isLittleEndian: true,
        valueType: DbcValueType.unsignedInt,
        factor: 1,
        offset: 0,
        minimum: 0,
        maximum: 0,
        unit: '',
        receivers: ['Vector__XXX'],
      );
      _selectedMessage!.signals.add(newSig);
      _selectedSignal = newSig;
      // Trigger update
      ref.read(dbcProvider.notifier).updateActiveDbc(ref.read(dbcProvider).activeDbc!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dbcState = ref.watch(dbcProvider);
    final activeDbc = dbcState.activeDbc;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DBC Editor'),
        scrolledUnderElevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = MediaQuery.of(context).size.width > 600;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isWide
                      ? TextButton.icon(
                          onPressed: () async {
                            if (!await _promptUnsavedChanges()) return;
                            ref.read(dbcProvider.notifier).addDbc(Dbc());
                          },
                          icon: const Icon(Icons.add_box),
                          label: const Text('New DBC'),
                        )
                      : IconButton(
                          onPressed: () async {
                            if (!await _promptUnsavedChanges()) return;
                            ref.read(dbcProvider.notifier).addDbc(Dbc());
                          },
                          icon: const Icon(Icons.add_box),
                          tooltip: 'New DBC',
                        ),
                  isWide
                      ? TextButton.icon(
                          onPressed: _loadDbc,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Load DBC'),
                        )
                      : IconButton(
                          onPressed: _loadDbc,
                          icon: const Icon(Icons.folder_open),
                          tooltip: 'Load DBC',
                        ),
                  isWide
                      ? TextButton.icon(
                          onPressed: activeDbc != null ? _saveDbc : null,
                          icon: const Icon(Icons.save),
                          label: const Text('Save DBC'),
                        )
                      : IconButton(
                          onPressed: activeDbc != null ? _saveDbc : null,
                          icon: const Icon(Icons.save),
                          tooltip: 'Save DBC',
                        ),
                  isWide
                      ? TextButton.icon(
                          onPressed: activeDbc != null
                              ? () async {
                                  if (!await _promptUnsavedChanges()) return;
                                  ref.read(dbcProvider.notifier).clearActiveDbc();
                                  setState(() {
                                    _selectedMessage = null;
                                    _selectedSignal = null;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.close),
                          label: const Text('Unload DBC'),
                        )
                      : IconButton(
                          onPressed: activeDbc != null
                              ? () async {
                                  if (!await _promptUnsavedChanges()) return;
                                  ref.read(dbcProvider.notifier).clearActiveDbc();
                                  setState(() {
                                    _selectedMessage = null;
                                    _selectedSignal = null;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.close),
                          tooltip: 'Unload DBC',
                        ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: activeDbc == null
          ? const Center(child: Text('No DBC loaded. Create or load one to begin.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 800;

                Widget messagesList = Container(
                  width: isNarrow ? double.infinity : 300,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Messages', style: Theme.of(context).textTheme.titleMedium),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _addMessage,
                              tooltip: 'Add Message',
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: activeDbc.messages.length,
                          itemBuilder: (context, index) {
                            final msg = activeDbc.messages[index];
                            final isSelected = msg == _selectedMessage;
                            return ListTile(
                              title: Text(msg.name),
                              subtitle: Text('ID: 0x${msg.id.toRadixString(16).toUpperCase()} | Len: ${msg.length}'),
                              selected: isSelected,
                              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                              onTap: () {
                                setState(() {
                                  _selectedMessage = msg;
                                  _selectedSignal = null;
                                });
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () {
                                  setState(() {
                                    activeDbc.messages.removeAt(index);
                                    if (_selectedMessage == msg) {
                                      _selectedMessage = null;
                                      _selectedSignal = null;
                                    }
                                    ref.read(dbcProvider.notifier).updateActiveDbc(activeDbc);
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );

                if (isNarrow) {
                  if (_selectedMessage == null) {
                    return messagesList;
                  } else {
                    return Column(
                      children: [
                        ListTile(
                          tileColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              setState(() {
                                _selectedMessage = null;
                                _selectedSignal = null;
                              });
                            },
                          ),
                          title: Text('Back to Messages', style: Theme.of(context).textTheme.titleMedium),
                        ),
                        const Divider(height: 1),
                        Expanded(child: _buildMessageEditor(context, isNarrow)),
                      ],
                    );
                  }
                }

                return Row(
                  children: [
                    messagesList,
                    Expanded(
                      child: _selectedMessage == null
                          ? const Center(child: Text('Select a message to edit'))
                          : _buildMessageEditor(context, isNarrow),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildMessageEditor(BuildContext context, bool isNarrow) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Message Details
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: _selectedMessage!.id.toRadixString(16).toUpperCase(),
                  decoration: const InputDecoration(labelText: 'ID (Hex)', border: OutlineInputBorder(), isDense: true),
                  onChanged: (val) {
                    final newId = int.tryParse(val, radix: 16);
                    if (newId != null) {
                      _selectedMessage!.id = newId;
                      ref.read(dbcProvider.notifier).updateActiveDbc(ref.read(dbcProvider).activeDbc!);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: TextFormField(
                  initialValue: _selectedMessage!.name,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), isDense: true),
                  onChanged: (val) {
                    _selectedMessage!.name = val;
                    ref.read(dbcProvider.notifier).updateActiveDbc(ref.read(dbcProvider).activeDbc!);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: _selectedMessage!.length.toString(),
                  decoration: const InputDecoration(labelText: 'Length', border: OutlineInputBorder(), isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final newLen = int.tryParse(val);
                    if (newLen != null) {
                      _selectedMessage!.length = newLen;
                      ref.read(dbcProvider.notifier).updateActiveDbc(ref.read(dbcProvider).activeDbc!);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Signals & Matrix Split
          Expanded(
            child: Flex(
              direction: isNarrow ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Signals List
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Signals', style: Theme.of(context).textTheme.titleMedium),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addSignal,
                            tooltip: 'Add Signal',
                          )
                        ],
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _selectedMessage!.signals.length,
                          itemBuilder: (context, index) {
                            final sig = _selectedMessage!.signals[index];
                            final isSelected = sig == _selectedSignal;
                            return ListTile(
                              title: Text(sig.name),
                              subtitle: Text('Start: ${sig.startBit} | Len: ${sig.length}'),
                              selected: isSelected,
                              selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
                              onTap: () {
                                setState(() {
                                  _selectedSignal = sig;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (isNarrow) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                ] else ...[
                  const SizedBox(width: 16),
                  const VerticalDivider(),
                  const SizedBox(width: 16),
                ],
                
                // Matrix & Form
                Expanded(
                  flex: 2,
                  child: _selectedSignal == null
                      ? const Center(child: Text('Select a signal to edit'))
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CanMatrixVisualizer(
                                message: _selectedMessage,
                                selectedSignal: _selectedSignal,
                                onBitTapped: (bitIndex) {
                                  setState(() {
                                    _selectedSignal!.startBit = bitIndex;
                                    ref.read(dbcProvider.notifier).updateActiveDbc(ref.read(dbcProvider).activeDbc!);
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              SignalEditorForm(
                                key: ObjectKey(_selectedSignal),
                                signal: _selectedSignal!,
                                onChanged: (updatedSig) {
                                  setState(() {
                                    final index = _selectedMessage!.signals.indexOf(_selectedSignal!);
                                    if (index != -1) {
                                      _selectedMessage!.signals[index] = updatedSig;
                                      _selectedSignal = updatedSig;
                                      ref.read(dbcProvider.notifier).updateActiveDbc(ref.read(dbcProvider).activeDbc!);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
