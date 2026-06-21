import 'dart:async';
import '../models/can_frame.dart';

/// The core abstraction for any CAN connection.
abstract class CanConnection {
  /// Whether this connection is a live data source.
  bool get isLive;

  /// Stream of frames received from the connection (batched for performance).
  Stream<List<CanFrame>> get frameStream;

  /// Sends a frame to the connection.
  Future<void> sendFrame(CanFrame frame);

  /// Initializes the connection.
  Future<void> connect();

  /// Closes the connection.
  Future<void> disconnect();
}
