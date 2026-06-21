import 'package:flutter/foundation.dart';

/// Represents a single CAN frame received or to be transmitted.
@immutable
class CanFrame {
  final double timestamp;
  final int id;
  final bool isExtended;
  final String direction;
  final int bus;
  final int length;
  final List<int> data;

  const CanFrame({
    required this.timestamp,
    required this.id,
    required this.isExtended,
    required this.direction,
    required this.bus,
    required this.length,
    required this.data,
  });

  /// Formatted timestamp (Relative Time).
  String get formattedTimestamp {
    double ts = timestamp;
    
    // SavvyCAN exports either relative Seconds (e.g., 12.345) or Microseconds (e.g., 12345000).
    // If the value is > 1 million, it's mathematically impossible to be a log length in seconds
    // (1 million seconds = 11.5 days, a CSV that size would be terabytes).
    // Therefore, any value > 1 million is guaranteed to be in microseconds.
    if (ts > 1000000) {
      ts = ts / 1000000.0;
    }

    final duration = Duration(microseconds: (ts * 1000000).round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    final millis = duration.inMilliseconds.remainder(1000);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
  }

  /// The hexadecimal representation of the ID.
  String get idHex {
    return id.toRadixString(16).toUpperCase().padLeft(isExtended ? 8 : 3, '0');
  }

  /// The hexadecimal representation of the data bytes.
  String get dataHex {
    return data.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
  }

  @override
  String toString() {
    return 'CanFrame(ts: $timestamp, id: $idHex, ext: $isExtended, dir: $direction, bus: $bus, len: $length, data: [$dataHex])';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CanFrame &&
        other.timestamp == timestamp &&
        other.id == id &&
        other.isExtended == isExtended &&
        other.direction == direction &&
        other.bus == bus &&
        other.length == length &&
        listEquals(other.data, data);
  }

  @override
  int get hashCode {
    return timestamp.hashCode ^
        id.hashCode ^
        isExtended.hashCode ^
        direction.hashCode ^
        bus.hashCode ^
        length.hashCode ^
        Object.hashAll(data);
  }
}
