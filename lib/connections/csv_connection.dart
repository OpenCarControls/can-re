import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import '../models/can_frame.dart';
import 'can_connection.dart';

/// A connection that reads from a GVRET-formatted CSV stream.
class CsvConnection implements CanConnection {
  final Stream<List<int>> csvStream;
  final _controller = StreamController<List<CanFrame>>.broadcast();
  
  CsvConnection(this.csvStream);

  @override
  bool get isLive => false;

  @override
  Stream<List<CanFrame>> get frameStream => _controller.stream;

  @override
  Future<void> connect() async {
    // Process the stream asynchronously in chunks
    List<CanFrame> buffer = [];
    bool isFirstRow = true;

    await for (final row in csvStream
        .transform(utf8.decoder)
        .transform(const CsvDecoder())) {
      
      if (row.isEmpty) continue;

      if (isFirstRow) {
        isFirstRow = false;
        if (row[0].toString().toLowerCase().contains('time stamp')) {
          continue; // Skip header
        }
      }

      if (row.length < 6) continue;

      try {
        final timestampStr = row[0].toString();
        final timestamp = double.tryParse(timestampStr) ?? 0.0;
        
        final idStr = row[1].toString().trim();
        final id = int.tryParse(idStr, radix: 16) ?? 0;
        
        final extendedStr = row[2].toString().trim().toLowerCase();
        final isExtended = extendedStr == 'true' || extendedStr == '1';
        
        final direction = row[3].toString().trim();
        
        final bus = int.tryParse(row[4].toString()) ?? 0;
        
        final length = int.tryParse(row[5].toString()) ?? 0;
        
        List<int> data = [];
        for (int d = 0; d < length; d++) {
          if (6 + d < row.length) {
            final byteStr = row[6 + d].toString().trim();
            final byte = int.tryParse(byteStr, radix: 16) ?? 0;
            data.add(byte);
          }
        }

        buffer.add(CanFrame(
          timestamp: timestamp,
          id: id,
          isExtended: isExtended,
          direction: direction,
          bus: bus,
          length: length,
          data: data,
        ));

      } catch (e) {
        debugPrint('Error parsing CSV row: $e');
      }
    }

    if (buffer.isNotEmpty) {
      _controller.add(buffer);
    }
    
    await _controller.close();
  }

  @override
  Future<void> disconnect() async {
    await _controller.close();
  }

  @override
  Future<void> sendFrame(CanFrame frame) async {
    throw UnimplementedError('Cannot send frames to a CSV file.');
  }
}
