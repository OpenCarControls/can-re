import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../connections/csv_connection.dart';
import 'frame_provider.dart';

class ConnectionStateData {
  final bool isLive;
  final bool isConnected;
  
  ConnectionStateData({this.isLive = false, this.isConnected = false});
}

class ConnectionNotifier extends StateNotifier<ConnectionStateData> {
  final Ref ref;
  CsvConnection? _currentConnection;

  ConnectionNotifier(this.ref) : super(ConnectionStateData());

  @override
  void dispose() {
    _currentConnection?.disconnect();
    super.dispose();
  }

  Future<void> loadCsv() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withReadStream: true,
    );

    if (result != null) {
      Stream<List<int>>? stream;

      if (kIsWeb) {
        stream = result.files.single.readStream;
      } else {
        final path = result.files.single.path;
        if (path != null) {
          stream = File(path).openRead();
        } else {
          stream = result.files.single.readStream;
        }
      }

      if (stream != null) {
        ref.read(frameProvider.notifier).clearFrames();
        ref.read(frameProvider.notifier).setLoading(true);
        _currentConnection?.disconnect();
        
        state = ConnectionStateData(isLive: false, isConnected: true);
        
        _currentConnection = CsvConnection(stream);
        _currentConnection!.frameStream.listen((framesChunk) {
          ref.read(frameProvider.notifier).addFrames(framesChunk);
        }, onDone: () {
          ref.read(frameProvider.notifier).setLoading(false);
        });
        
        await _currentConnection!.connect();
      }
    }
  }

  void saveCsv() {
    // To be implemented
  }

  void connectLive() {
    // To be implemented
  }

  void disconnect() {
    _currentConnection?.disconnect();
    _currentConnection = null;
    state = ConnectionStateData(isLive: false, isConnected: false);
  }
}

final connectionProvider = StateNotifierProvider<ConnectionNotifier, ConnectionStateData>((ref) {
  return ConnectionNotifier(ref);
});
