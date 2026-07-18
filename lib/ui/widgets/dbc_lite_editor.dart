import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/can_frame.dart';
import '../../models/dbc_model.dart';
import '../../providers/dbc_provider.dart';
import '../../utils/dbc_decoder.dart';
import 'can_matrix_visualizer.dart';
import 'signal_editor_form.dart';

class DbcLiteEditor extends ConsumerStatefulWidget {
  final CanFrame frame;

  const DbcLiteEditor({super.key, required this.frame});

  @override
  ConsumerState<DbcLiteEditor> createState() => _DbcLiteEditorState();
}

class _DbcLiteEditorState extends ConsumerState<DbcLiteEditor> {
  late DbcMessage _currentMessage;
  DbcSignal? _selectedSignal;
  late TextEditingController _messageNameController;
  late String _initialMessageHash;

  @override
  void initState() {
    super.initState();
    _initMessage();
  }

  void _initMessage() {
    final activeDbc = ref.read(dbcProvider).activeDbc;
    DbcMessage? existingMsg;

    if (activeDbc != null) {
      final msgId = widget.frame.id;
      existingMsg = activeDbc.messages.where((m) => m.id == msgId).firstOrNull;
    }

    if (existingMsg != null) {
      // Copy to allow editing without immediately mutating state until saved
      _currentMessage = DbcMessage(
        id: existingMsg.id,
        name: existingMsg.name,
        length: existingMsg.length,
        transmitter: existingMsg.transmitter,
        signals: List.from(existingMsg.signals),
      );
    } else {
      _currentMessage = DbcMessage(
        id: widget.frame.id,
        name: 'MSG_${widget.frame.idHex}',
        length: widget.frame.length,
        transmitter: 'Vector__XXX',
        signals: [],
      );
    }

    _messageNameController = TextEditingController(text: _currentMessage.name);
    _initialMessageHash = _getMessageHash(_currentMessage);
  }

  String _getMessageHash(DbcMessage msg) {
    return msg.toDbcString() + '\n' + msg.signals.map((s) => s.toDbcString()).join('\n');
  }

  Future<bool> _promptClose() async {
    _currentMessage.name = _messageNameController.text;
    final currentHash = _getMessageHash(_currentMessage);
    if (currentHash != _initialMessageHash) {
      final shouldClose = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('You have unsaved changes in this message. Are you sure you want to close without saving?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Close without Saving'),
            ),
          ],
        ),
      );
      return shouldClose ?? false;
    }
    return true;
  }

  @override
  void dispose() {
    _messageNameController.dispose();
    super.dispose();
  }

  void _saveToActiveDbc() {
    var activeDbc = ref.read(dbcProvider).activeDbc;
    bool isNewDbc = false;
    
    if (activeDbc == null) {
      activeDbc = Dbc();
      isNewDbc = true;
    }

    _currentMessage.name = _messageNameController.text;

    final existingIndex = activeDbc.messages.indexWhere((m) => m.id == _currentMessage.id);
    if (existingIndex != -1) {
      activeDbc.messages[existingIndex] = _currentMessage;
    } else {
      activeDbc.messages.add(_currentMessage);
    }

    if (isNewDbc) {
      ref.read(dbcProvider.notifier).addDbc(activeDbc);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created new DBC and saved ${_currentMessage.name}.')),
      );
    } else {
      ref.read(dbcProvider.notifier).updateActiveDbc(activeDbc);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${_currentMessage.name} to active DBC.')),
      );
    }
    
    // Close editor on save
    if (mounted) Navigator.of(context).pop();
  }

  void _addSignal() {
    setState(() {
      final newSig = DbcSignal(
        name: 'New_Signal_${_currentMessage.signals.length + 1}',
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
      _currentMessage.signals.add(newSig);
      _selectedSignal = newSig;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _promptClose();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '0x${widget.frame.idHex}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _messageNameController,
                      decoration: const InputDecoration(
                        labelText: 'Message Name',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: _saveToActiveDbc,
                    icon: const Icon(Icons.save),
                    label: const Text('Save to Active DBC'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      if (await _promptClose()) {
                        if (mounted) Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.close),
                    tooltip: 'Close Editor',
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  return Flex(
                    direction: isNarrow ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side: Signals list
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Signals', style: Theme.of(context).textTheme.titleSmall),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: _addSignal,
                                  tooltip: 'Add Signal',
                                )
                              ],
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _currentMessage.signals.length,
                                itemBuilder: (context, index) {
                                  final sig = _currentMessage.signals[index];
                                  final isSelected = sig == _selectedSignal;
                                  
                                  // Decode live value
                                  String decodedText = '';
                                  try {
                                    final decoded = DbcDecoder.decodeSignal(widget.frame.data, sig);
                                    decodedText = decoded.formattedValue;
                                  } catch (e) {
                                    decodedText = 'Error';
                                  }

                                  return ListTile(
                                    title: Text(sig.name, style: const TextStyle(fontSize: 14)),
                                    subtitle: Text('Start: ${sig.startBit} | Len: ${sig.length} => $decodedText'),
                                    selected: isSelected,
                                    selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                                    dense: true,
                                    onTap: () {
                                      setState(() {
                                        _selectedSignal = sig;
                                      });
                                    },
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, size: 16),
                                      onPressed: () {
                                        setState(() {
                                          _currentMessage.signals.removeAt(index);
                                          if (_selectedSignal == sig) _selectedSignal = null;
                                        });
                                      },
                                    ),
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
                        const VerticalDivider(width: 1),
                        const SizedBox(width: 16),
                      ],
                      
                      // Right side: Signal Editor & Matrix
                  Expanded(
                    flex: 2,
                    child: _selectedSignal == null
                        ? const Center(child: Text('Select or add a signal to edit'))
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CanMatrixVisualizer(
                            message: _currentMessage,
                            selectedSignal: _selectedSignal,
                            payload: widget.frame.data,
                            onBitTapped: (bit) {
                              if (_selectedSignal != null) {
                                setState(() {
                                  _selectedSignal!.startBit = bit;
                                });
                              }
                            },
                          ),      const SizedBox(height: 16),
                                SignalEditorForm(
                                  signal: _selectedSignal!,
                                  onChanged: (updatedSig) {
                                    setState(() {
                                      final index = _currentMessage.signals.indexOf(_selectedSignal!);
                                      if (index != -1) {
                                        _currentMessage.signals[index] = updatedSig;
                                        _selectedSignal = updatedSig;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                  ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
