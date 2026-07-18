import 'dart:convert';
import 'package:flutter/foundation.dart';

enum DbcValueType {
  unsignedInt,
  signedInt,
  float32,
  float64,
  string,
}

class DbcSignal {
  String name;
  String multiplexerIndicator; // "M", "m1", or ""
  int startBit;
  int length;
  bool isLittleEndian; // true = 1 (Intel), false = 0 (Motorola)
  DbcValueType valueType;
  double factor;
  double offset;
  double minimum;
  double maximum;
  String unit;
  List<String> receivers;
  Map<int, String> valueTable;

  DbcSignal({
    required this.name,
    this.multiplexerIndicator = '',
    required this.startBit,
    required this.length,
    required this.isLittleEndian,
    required this.valueType,
    required this.factor,
    required this.offset,
    required this.minimum,
    required this.maximum,
    required this.unit,
    required this.receivers,
    this.valueTable = const {},
  });

  factory DbcSignal.parse(String line) {
    // SG_ SignalName [MultiplexerIndicator] : StartBit|Length@EndiannessSigned (Factor,Offset) [Min|Max] "Unit" Receiver1,Receiver2
    // Example: SG_ EngineSpeed : 24|16@1+ (0.1,0) [0|8000] "rpm" Vector__XXX
    // Example: SG_ MultiplexedSig m1 : 16|8@1+ (1,0) [0|255] "" Vector__XXX
    
    // Quick regex to parse:
    final regex = RegExp(r'SG_\s+(\w+)\s*(M|m\d+)?\s*:\s*(\d+)\|(\d+)@([01])([+-])\s*\(([^,]+),([^)]+)\)\s*\[([^|]+)\|([^\]]+)\]\s*"([^"]*)"\s*(.*)');
    final match = regex.firstMatch(line.trim());

    if (match == null) {
      throw FormatException('Invalid SG_ format: $line');
    }

    return DbcSignal(
      name: match.group(1)!,
      multiplexerIndicator: match.group(2) ?? '',
      startBit: int.parse(match.group(3)!),
      length: int.parse(match.group(4)!),
      isLittleEndian: match.group(5) == '1',
      valueType: match.group(6) == '-' ? DbcValueType.signedInt : DbcValueType.unsignedInt,
      factor: double.parse(match.group(7)!),
      offset: double.parse(match.group(8)!),
      minimum: double.parse(match.group(9)!),
      maximum: double.parse(match.group(10)!),
      unit: match.group(11) ?? '',
      receivers: match.group(12)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      valueTable: {},
    );
  }

  String toDbcString() {
    String endian = isLittleEndian ? '1' : '0';
    String sign = (valueType == DbcValueType.signedInt || valueType == DbcValueType.float32 || valueType == DbcValueType.float64) ? '-' : '+';
    String mux = multiplexerIndicator.isNotEmpty ? ' $multiplexerIndicator ' : ' ';
    String rcvrs = receivers.isEmpty ? 'Vector__XXX' : receivers.join(',');
    return ' SG_ $name$mux: $startBit|$length@$endian$sign (${_formatDouble(factor)},${_formatDouble(offset)}) [${_formatDouble(minimum)}|${_formatDouble(maximum)}] "$unit" $rcvrs';
  }

  String _formatDouble(double val) {
    if (val == val.toInt()) {
      return val.toInt().toString();
    }
    return val.toString();
  }
}

class DbcMessage {
  int id;
  String name;
  int length;
  String transmitter;
  List<DbcSignal> signals;

  DbcMessage({
    required this.id,
    required this.name,
    required this.length,
    required this.transmitter,
    this.signals = const [],
  });

  factory DbcMessage.parse(String line) {
    // BO_ MessageId MessageName: MessageSize Transmitter
    // Example: BO_ 512 EngineData: 8 EngineNode
    final regex = RegExp(r'BO_\s+(\d+)\s+(\w+)\s*:\s*(\d+)\s+(\w+)');
    final match = regex.firstMatch(line.trim());

    if (match == null) {
      throw FormatException('Invalid BO_ format: $line');
    }

    return DbcMessage(
      id: int.parse(match.group(1)!),
      name: match.group(2)!,
      length: int.parse(match.group(3)!),
      transmitter: match.group(4)!,
      signals: [],
    );
  }

  String toDbcString() {
    return 'BO_ $id $name: $length $transmitter';
  }
}

class Dbc {
  List<DbcMessage> messages = [];
  List<String> unparsedLines = []; // Store lines we don't actively edit so we can save them back if needed

  // A simplified parser that focuses on BO_, SG_, and VAL_
  static Dbc parse(String content) {
    final dbc = Dbc();
    final lines = const LineSplitter().convert(content);
    
    DbcMessage? currentMessage;
    
    // To handle value tables later
    final valLines = <String>[];
    // To handle extended signal types (SIG_VALTYPE_)
    final sigValTypeLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('BO_ ')) {
        try {
          currentMessage = DbcMessage.parse(trimmed);
          dbc.messages.add(currentMessage);
        } catch (e) {
          debugPrint('Error parsing BO_: $e');
          dbc.unparsedLines.add(line);
        }
      } else if (trimmed.startsWith('SG_ ')) {
        if (currentMessage != null) {
          try {
            final signal = DbcSignal.parse(trimmed);
            currentMessage.signals.add(signal);
          } catch (e) {
            debugPrint('Error parsing SG_: $e');
            dbc.unparsedLines.add(line);
          }
        } else {
          dbc.unparsedLines.add(line);
        }
      } else if (trimmed.startsWith('VAL_ ')) {
        valLines.add(trimmed);
      } else if (trimmed.startsWith('SIG_VALTYPE_ ')) {
        sigValTypeLines.add(trimmed);
      } else {
        dbc.unparsedLines.add(line);
      }
    }

    // Process VAL_ lines
    for (final line in valLines) {
      // VAL_ MessageId SignalName Value "Description" Value "Description" ;
      final match = RegExp(r'VAL_\s+(\d+)\s+(\w+)\s+(.*);').firstMatch(line);
      if (match != null) {
        final msgId = int.tryParse(match.group(1)!);
        final sigName = match.group(2)!;
        final pairsStr = match.group(3)!;

        // Find the message and signal
        final msg = dbc.messages.where((m) => m.id == msgId).firstOrNull;
        if (msg != null) {
          final sig = msg.signals.where((s) => s.name == sigName).firstOrNull;
          if (sig != null) {
            // Parse pairs
            final pairRegex = RegExp(r'(\d+)\s+"([^"]*)"');
            final pairs = pairRegex.allMatches(pairsStr);
            final valTable = <int, String>{};
            for (final p in pairs) {
              valTable[int.parse(p.group(1)!)] = p.group(2)!;
            }
            sig.valueTable = valTable;
            continue; // Successfully parsed
          }
        }
      }
      dbc.unparsedLines.add(line); // Fallback if we couldn't attach it
    }

    // Process SIG_VALTYPE_ lines
    for (final line in sigValTypeLines) {
      // SIG_VALTYPE_ MessageId SignalName Type;
      final match = RegExp(r'SIG_VALTYPE_\s+(\d+)\s+(\w+)\s*:\s*(\d+);').firstMatch(line);
      if (match != null) {
        final msgId = int.tryParse(match.group(1)!);
        final sigName = match.group(2)!;
        final typeVal = int.tryParse(match.group(3)!);

        final msg = dbc.messages.where((m) => m.id == msgId).firstOrNull;
        if (msg != null) {
          final sig = msg.signals.where((s) => s.name == sigName).firstOrNull;
          if (sig != null && typeVal != null) {
            if (typeVal == 1) {
              sig.valueType = DbcValueType.float32;
            } else if (typeVal == 2) {
              sig.valueType = DbcValueType.float64;
            } else if (typeVal == 3) {
              sig.valueType = DbcValueType.string;
            }
            continue; // Successfully parsed
          }
        }
      }
      dbc.unparsedLines.add(line); // Fallback
    }

    return dbc;
  }

  String toDbcString() {
    final sb = StringBuffer();
    sb.writeln('VERSION ""');
    sb.writeln();
    sb.writeln('NS_ :');
    sb.writeln();
    sb.writeln('BS_:');
    sb.writeln();
    sb.writeln('BU_: '); // Simplified, would need actual parsing if we want to keep them
    sb.writeln();

    for (final msg in messages) {
      sb.writeln(msg.toDbcString());
      for (final sig in msg.signals) {
        sb.writeln(sig.toDbcString());
      }
      sb.writeln();
    }

    // Write value tables
    for (final msg in messages) {
      for (final sig in msg.signals) {
        if (sig.valueTable.isNotEmpty) {
          sb.write('VAL_ ${msg.id} ${sig.name}');
          sig.valueTable.forEach((val, desc) {
            sb.write(' $val "$desc"');
          });
          sb.writeln(' ;');
        }
      }
    }

    // Write extended signal types
    for (final msg in messages) {
      for (final sig in msg.signals) {
        if (sig.valueType == DbcValueType.float32) {
          sb.writeln('SIG_VALTYPE_ ${msg.id} ${sig.name} : 1;');
        } else if (sig.valueType == DbcValueType.float64) {
          sb.writeln('SIG_VALTYPE_ ${msg.id} ${sig.name} : 2;');
        } else if (sig.valueType == DbcValueType.string) {
          sb.writeln('SIG_VALTYPE_ ${msg.id} ${sig.name} : 3;');
        }
      }
    }

    // Add back unparsed lines at the end (a bit hacky but preserves other tags roughly)
    // Actually, properly preserving all lines and inserting edits is very complex.
    // We will just append them for now.
    sb.writeln();
    for (final line in unparsedLines) {
      if (!line.startsWith('VERSION') && !line.startsWith('NS_') && !line.startsWith('BS_') && !line.startsWith('BU_')) {
        sb.writeln(line);
      }
    }

    return sb.toString();
  }
}
