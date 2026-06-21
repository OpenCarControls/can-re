# Agent Rules for OpenCarControls - CAN RE

These rules guide any AI agent working within the OpenCarControls CAN RE workspace.

## Tech Stack & Architecture
- **Framework**: Flutter (Multi-platform: Web, Desktop, Mobile).
- **State Management**: `flutter_riverpod` ONLY. Do not introduce `provider`, `bloc`, or `getx`.
- **Routing**: `go_router`.
- **Aesthetics**: Follow the "Rich Aesthetics" guidelines (premium feel, modern typography via `google_fonts`, dynamic/responsive layout).

## Connection Abstraction Layer (CRITICAL)
- The app supports diverse connections (CSV, Serial, Network, SocketCAN).
- **Never** tightly couple a UI component to a specific hardware implementation.
- All protocols must implement the base `CanConnection` interface.
- **Conditional Imports**: Since we target both Web and Desktop/Mobile natively:
  - `flutter_libserialport` and `linux_can` **MUST NOT** be imported in code that compiles for the Web.
  - `serial` (Web Serial API) **MUST NOT** be imported in code that compiles for Desktop/Mobile.
  - You must use Dart conditional imports (`if (dart.library.html) ...` or `if (dart.library.io) ...`) to build factories that select the appropriate hardware driver at compile-time.

## Code Conventions
- Document public APIs using standard Dart doc comments `///`.
- Write clean, declarative Flutter code.
- Prefer Riverpod `ConsumerWidget` or `ConsumerStatefulWidget` over `Consumer` builders where appropriate for entire screens.
