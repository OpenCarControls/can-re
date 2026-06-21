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
- Prefer Riverpod `ConsumerWidget` or `ConsumerStatefulWidget` over `Consumer` builders where appropriate for entire screens.

## Data Processing
- **Timestamps (CRITICAL)**: Assume CAN timestamps (e.g. from SavvyCAN CSVs or hardware adapters) are relative microsecond counters since the device booted or the log started. Do **not** attempt to parse large numeric timestamps as absolute Unix Epoch dates (unless explicitly specified), as this leads to integer overflow and massive timeline distortion. Format them as relative duration (`HH:mm:ss.SSS`).

## UI Architecture
- **Responsive Dashboard**: Use a `LayoutBuilder` to adapt between desktop (persistent right sidebar, >800px) and mobile (`EndDrawer`).
- **Data Tables**: Use flexible widths (`Expanded` inside a `Row`) wrapped in a horizontal `SingleChildScrollView` with a minimum width to prevent columns from being squished into oblivion on narrow screens.
