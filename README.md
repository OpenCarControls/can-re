# OpenCarControls - CAN RE

A modern, high-performance, cross-platform CAN (Controller Area Network) reverse engineering tool, built with Flutter. Inspired by SavvyCAN, but designed from the ground up for cross-platform support and a rich, modern user interface.

## Features

- **Cross-Platform**: Runs natively on Desktop (Windows, macOS, Linux), Mobile (Android, iOS), and Web (PWA).
- **Multiple Protocols**: Seamlessly connects to different CAN interfaces:
  - **CSV Logs**: Read and analyze captured CAN data.
  - **Serial**: Standard serial port communication for hardware adapters (uses Web Serial API on Web, native libserialport on desktop).
  - **Network**: TCP/UDP and WebSocket support.
  - **SocketCAN**: Direct integration for Linux environments.
- **Rich Aesthetics**: A premium, responsive interface optimized for visualizing high-speed data streams.
- **High-Performance Data Grid**: Virtualized lists capable of parsing and rendering millions of frames instantly without blocking the UI thread.
- **Responsive Dashboard**: Scalable Flex layout with a permanent sidebar on Desktop, gracefully degrading to an `EndDrawer` on Mobile. Features toggleable columns and horizontal scroll protection.
- **"Twitch-Style" Live Scrolling**: Automatically locks your visual position when scrolling up to analyze past frames, without being forcefully interrupted by incoming live data.
## Getting Started

This project is built using [Flutter](https://flutter.dev/).

### Prerequisites

- Flutter SDK (latest stable)
- For Linux SocketCAN support: ensure `libsocketcan` is available.
- For Desktop serial support: `libserialport` is bundled via FFI, but ensure appropriate permissions on your platform.

### Running the App

```bash
# Get dependencies
flutter pub get

# Run on your current platform
flutter run
```

## Architecture

This project strictly separates hardware/connection specifics from the core UI via a **Connection Abstraction Layer**. Platform-specific implementations (like Web vs Desktop serial) are resolved at compile-time using Dart's conditional imports to ensure maximum portability without compilation errors.
