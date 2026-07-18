import 'package:flutter/material.dart';
import '../../models/dbc_model.dart';

enum MultiplexerRole { none, multiplexor, multiplexed }

class SignalEditorForm extends StatefulWidget {
  final DbcSignal signal;
  final ValueChanged<DbcSignal> onChanged;

  const SignalEditorForm({
    super.key,
    required this.signal,
    required this.onChanged,
  });

  @override
  State<SignalEditorForm> createState() => _SignalEditorFormState();
}

class _SignalEditorFormState extends State<SignalEditorForm> {
  late TextEditingController _nameController;
  late TextEditingController _lengthController;
  late TextEditingController _factorController;
  late TextEditingController _offsetController;
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _unitController;
  
  MultiplexerRole _muxRole = MultiplexerRole.none;
  late TextEditingController _muxValueController;

  DbcSignal? _lastEmittedSignal;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant SignalEditorForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signal != widget.signal && widget.signal != _lastEmittedSignal) {
      // Only re-init controllers if the parent passed a genuinely different signal
      // that we didn't just emit ourselves (which resets the caret position).
      _nameController.text = widget.signal.name;
      _lengthController.text = widget.signal.length.toString();
      _factorController.text = widget.signal.factor.toString();
      _offsetController.text = widget.signal.offset.toString();
      _minController.text = widget.signal.minimum.toString();
      _maxController.text = widget.signal.maximum.toString();
      _unitController.text = widget.signal.unit;

      _muxRole = MultiplexerRole.none;
      if (widget.signal.multiplexerIndicator == 'M') {
        _muxRole = MultiplexerRole.multiplexor;
      } else if (widget.signal.multiplexerIndicator.startsWith('m')) {
        _muxRole = MultiplexerRole.multiplexed;
        _muxValueController.text = widget.signal.multiplexerIndicator.substring(1);
      } else {
        _muxValueController.text = '';
      }
    }
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.signal.name);
    _lengthController = TextEditingController(text: widget.signal.length.toString());
    _factorController = TextEditingController(text: widget.signal.factor.toString());
    _offsetController = TextEditingController(text: widget.signal.offset.toString());
    _minController = TextEditingController(text: widget.signal.minimum.toString());
    _maxController = TextEditingController(text: widget.signal.maximum.toString());
    _unitController = TextEditingController(text: widget.signal.unit);
    
    _muxRole = MultiplexerRole.none;
    _muxValueController = TextEditingController();
    if (widget.signal.multiplexerIndicator == 'M') {
      _muxRole = MultiplexerRole.multiplexor;
    } else if (widget.signal.multiplexerIndicator.startsWith('m')) {
      _muxRole = MultiplexerRole.multiplexed;
      _muxValueController.text = widget.signal.multiplexerIndicator.substring(1);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lengthController.dispose();
    _factorController.dispose();
    _offsetController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _unitController.dispose();
    _muxValueController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    String muxInd = '';
    if (_muxRole == MultiplexerRole.multiplexor) {
      muxInd = 'M';
    } else if (_muxRole == MultiplexerRole.multiplexed) {
      muxInd = 'm${_muxValueController.text}';
    }

    final newSignal = DbcSignal(
      name: _nameController.text,
      multiplexerIndicator: muxInd,
      startBit: widget.signal.startBit,
      length: int.tryParse(_lengthController.text) ?? widget.signal.length,
      isLittleEndian: widget.signal.isLittleEndian,
      valueType: widget.signal.valueType,
      factor: double.tryParse(_factorController.text) ?? widget.signal.factor,
      offset: double.tryParse(_offsetController.text) ?? widget.signal.offset,
      minimum: double.tryParse(_minController.text) ?? widget.signal.minimum,
      maximum: double.tryParse(_maxController.text) ?? widget.signal.maximum,
      unit: _unitController.text,
      receivers: widget.signal.receivers,
      valueTable: widget.signal.valueTable,
    );
    _lastEmittedSignal = newSignal;
    widget.onChanged(newSignal);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name', isDense: true),
                  onChanged: (_) => _notifyChange(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _lengthController,
                  decoration: const InputDecoration(labelText: 'Length (bits)', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _notifyChange(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<MultiplexerRole>(
                  initialValue: _muxRole,
                  decoration: const InputDecoration(labelText: 'Multiplexing', isDense: true),
                  items: const [
                    DropdownMenuItem(value: MultiplexerRole.none, child: Text('None')),
                    DropdownMenuItem(value: MultiplexerRole.multiplexor, child: Text('Multiplexor (M)')),
                    DropdownMenuItem(value: MultiplexerRole.multiplexed, child: Text('Multiplexed (mX)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _muxRole = val;
                        _notifyChange();
                      });
                    }
                  },
                ),
              ),
              if (_muxRole == MultiplexerRole.multiplexed) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _muxValueController,
                    decoration: const InputDecoration(labelText: 'Mux Value', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                const Expanded(flex: 1, child: SizedBox.shrink()),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<DbcValueType>(
                  initialValue: widget.signal.valueType,
                  decoration: const InputDecoration(labelText: 'Value Type', isDense: true),
                  items: const [
                    DropdownMenuItem(value: DbcValueType.unsignedInt, child: Text('Unsigned Int (+)')),
                    DropdownMenuItem(value: DbcValueType.signedInt, child: Text('Signed Int (-)')),
                    DropdownMenuItem(value: DbcValueType.float32, child: Text('Float (32-bit)')),
                    DropdownMenuItem(value: DbcValueType.float64, child: Text('Double (64-bit)')),
                    DropdownMenuItem(value: DbcValueType.string, child: Text('String')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      widget.signal.valueType = val;
                      _notifyChange();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: CheckboxListTile(
                  title: const Text('Little Endian', style: TextStyle(fontSize: 14)),
                  value: widget.signal.isLittleEndian,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) {
                    if (val != null) {
                      widget.signal.isLittleEndian = val;
                      _notifyChange();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _factorController,
                  decoration: const InputDecoration(labelText: 'Factor', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _notifyChange(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _offsetController,
                  decoration: const InputDecoration(labelText: 'Offset', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _notifyChange(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _minController,
                  decoration: const InputDecoration(labelText: 'Min', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _notifyChange(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _maxController,
                  decoration: const InputDecoration(labelText: 'Max', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _notifyChange(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _unitController,
                  decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                  onChanged: (_) => _notifyChange(),
                ),
              ),
            ],
          ),
          // Value Table Viewer
          if (widget.signal.valueTable.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Value Table', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.signal.valueTable.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text('${e.key}: ${e.value}'),
                  );
                }).toList(),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
