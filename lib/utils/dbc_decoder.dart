import 'dart:typed_data';
import '../models/can_frame.dart';
import '../models/dbc_model.dart';

class DecodedSignal {
  final DbcSignal signal;
  final double physicalValue;
  final String? stringValue;

  DecodedSignal({
    required this.signal,
    required this.physicalValue,
    this.stringValue,
  });

  String get formattedValue {
    if (stringValue != null) {
      return stringValue!;
    }
    
    // Format to remove trailing zeros
    String valStr;
    if (physicalValue == physicalValue.toInt()) {
      valStr = physicalValue.toInt().toString();
    } else {
      valStr = physicalValue.toStringAsFixed(3).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    }

    if (signal.unit.isNotEmpty) {
      return '$valStr ${signal.unit}';
    }
    return valStr;
  }
}

class DecodedMessage {
  final DbcMessage message;
  final List<DecodedSignal> decodedSignals;

  DecodedMessage({
    required this.message,
    required this.decodedSignals,
  });
}

class DbcDecoder {
  /// Decodes a CanFrame using the provided active DBC.
  /// Returns a DecodedMessage if the message ID exists in the DBC, or null otherwise.
  static DecodedMessage? decode(Dbc dbc, CanFrame frame) {
    final message = dbc.messages.where((m) => m.id == frame.id).firstOrNull;
    if (message == null) return null;

    final decodedSignals = <DecodedSignal>[];

    // First pass: find if there's a multiplexer signal
    DbcSignal? multiplexerSignal;
    for (final sig in message.signals) {
      if (sig.multiplexerIndicator == 'M') {
        multiplexerSignal = sig;
        break;
      }
    }

    int? muxValue;
    if (multiplexerSignal != null) {
      final rawMux = extractRawValue(frame.data, multiplexerSignal);
      // Mux is always unsigned
      muxValue = rawMux.toInt();
      
      // Decode the multiplexer itself
      decodedSignals.add(decodeSignal(frame.data, multiplexerSignal));
    }

    // Second pass: decode signals that match the multiplexer state (or are not multiplexed)
    for (final sig in message.signals) {
      if (sig == multiplexerSignal) continue;

      if (sig.multiplexerIndicator.startsWith('m')) {
        // This is a multiplexed signal. e.g. "m1" -> mux value must be 1.
        final requiredMux = int.tryParse(sig.multiplexerIndicator.substring(1));
        if (requiredMux != null && requiredMux != muxValue) {
          continue; // Skip, mux doesn't match
        }
      }

      decodedSignals.add(decodeSignal(frame.data, sig));
    }

    return DecodedMessage(message: message, decodedSignals: decodedSignals);
  }

  static DecodedSignal decodeSignal(List<int> payload, DbcSignal signal) {
    final rawValue = extractRawValue(payload, signal);
    
    double physicalValue;
    if (signal.valueType == DbcValueType.float32) {
      // Reinterpret the raw 32-bit int as float32
      final bytes = ByteData(4)..setUint32(0, rawValue.toInt(), Endian.little);
      physicalValue = bytes.getFloat32(0, Endian.little);
    } else if (signal.valueType == DbcValueType.float64) {
      // Reinterpret the raw 64-bit int as float64
      final bytes = ByteData(8)..setUint64(0, rawValue.toInt(), Endian.little);
      physicalValue = bytes.getFloat64(0, Endian.little);
    } else {
      // Int types (signed and unsigned)
      int valueToScale = rawValue.toInt();
      
      if (signal.valueType == DbcValueType.signedInt) {
        // Apply two's complement if it's negative
        if ((valueToScale & (1 << (signal.length - 1))) != 0) {
          // Negative
          // E.g. an 8-bit signal of 0xFF (255) is -1.
          // Invert bits, add 1, and make negative. Or just extend the sign bit to 64 bits.
          final mask = (1 << signal.length) - 1;
          final inverted = (~valueToScale) & mask;
          valueToScale = -(inverted + 1);
        }
      }
      
      physicalValue = (valueToScale * signal.factor) + signal.offset;
    }

    // Look up value table
    String? stringValue;
    if (signal.valueTable.isNotEmpty) {
      final intPhysical = physicalValue.toInt();
      if (physicalValue == intPhysical && signal.valueTable.containsKey(intPhysical)) {
        stringValue = signal.valueTable[intPhysical];
      }
    }

    return DecodedSignal(
      signal: signal,
      physicalValue: physicalValue,
      stringValue: stringValue,
    );
  }

  /// Extracts the raw integer value of a signal from the payload.
  static BigInt extractRawValue(List<int> payload, DbcSignal signal) {
    final bits = <int>[];
    if (signal.isLittleEndian) {
      // Intel: startBit is LSB
      for (int i = 0; i < signal.length; i++) {
        bits.add(signal.startBit + i);
      }
    } else {
      // Motorola: startBit is MSB
      int currentBit = signal.startBit;
      for (int i = 0; i < signal.length; i++) {
        bits.add(currentBit);
        if (currentBit % 8 == 0) {
          currentBit += 15;
        } else {
          currentBit -= 1;
        }
      }
    }

    BigInt raw = BigInt.zero;
    for (int i = 0; i < bits.length; i++) {
      final bitIndex = bits[i];
      final byteIndex = bitIndex ~/ 8;
      final bitInByte = bitIndex % 8;

      if (byteIndex < payload.length) {
        final bitValue = (payload[byteIndex] >> bitInByte) & 1;
        if (bitValue == 1) {
          final shift = signal.isLittleEndian ? i : (signal.length - 1 - i);
          raw |= BigInt.from(1) << shift;
        }
      }
    }

    return raw;
  }
}
