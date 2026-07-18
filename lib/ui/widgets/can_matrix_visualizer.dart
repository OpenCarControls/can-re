import 'package:flutter/material.dart';
import '../../models/dbc_model.dart';

class CanMatrixVisualizer extends StatelessWidget {
  final DbcMessage? message;
  final DbcSignal? selectedSignal;
  final void Function(int)? onBitTapped;
  final List<int>? payload;

  const CanMatrixVisualizer({
    super.key,
    this.message,
    this.selectedSignal,
    this.onBitTapped,
    this.payload,
  });

  Set<int> _getSignalBits(DbcSignal sig) {
    final bits = <int>{};
    if (sig.isLittleEndian) {
      for (int i = 0; i < sig.length; i++) {
        bits.add(sig.startBit + i);
      }
    } else {
      // Motorola (Big Endian)
      // DBC Motorola start bit is the MSB.
      int currentBit = sig.startBit;
      for (int i = 0; i < sig.length; i++) {
        bits.add(currentBit);
        if (currentBit % 8 == 0) {
          currentBit += 15;
        } else {
          currentBit -= 1;
        }
      }
    }
    return bits;
  }

  @override
  Widget build(BuildContext context) {
    // 8 bytes (rows), 8 bits per byte (columns)
    // Row 0 is Byte 0.
    // Within a row, left is Bit 7, right is Bit 0.

    final msgLength = message?.length ?? 8;
    final maxBytes = msgLength > 8 ? msgLength : 8; // Usually 8 for classic CAN, up to 64 for CAN FD
    // For simplicity, we just show an 8x8 grid. If length > 8, we could show more rows.
    final displayRows = maxBytes > 64 ? 64 : maxBytes;

    Set<int> selectedBits = {};
    if (selectedSignal != null) {
      selectedBits = _getSignalBits(selectedSignal!);
    }

    // Map each bit to a signal to color code them
    final bitToSignal = <int, DbcSignal>{};
    if (message != null) {
      for (final sig in message!.signals) {
        final bits = _getSignalBits(sig);
        for (final b in bits) {
          bitToSignal[b] = sig;
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 8 columns * 2px margin = 16px extra space needed
        final cellSize = (constraints.maxWidth - 40 - 16) / 8; 
        final clampedCellSize = cellSize > 32.0 ? 32.0 : cellSize; // max 32px

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 40), // Label space
                ...List.generate(8, (col) {
                  return SizedBox(
                    width: clampedCellSize,
                    child: Center(
                      child: Text(
                        '${7 - col}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 4),
            ...List.generate(displayRows, (row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        'B$row',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ...List.generate(8, (col) {
                      final bitIndex = row * 8 + (7 - col);
                      
                      final sigAtBit = bitToSignal[bitIndex];
                      final isSelected = selectedBits.contains(bitIndex);
                      final isOtherSignal = sigAtBit != null && sigAtBit != selectedSignal;

                      Color cellColor = Theme.of(context).colorScheme.surfaceContainerHighest;
                      Color borderColor = Theme.of(context).colorScheme.outlineVariant;

                      if (isSelected) {
                        cellColor = Theme.of(context).colorScheme.primaryContainer;
                        borderColor = Theme.of(context).colorScheme.primary;
                      } else if (isOtherSignal) {
                        cellColor = Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5);
                        borderColor = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5);
                      }

                      // MSB / LSB marker
                      String label = '';
                      String bitValStr = '';

                      if (payload != null && row < payload!.length) {
                        bitValStr = ((payload![row] >> (7 - col)) & 1).toString();
                      }

                      if (selectedSignal != null && isSelected) {
                        if (bitIndex == selectedSignal!.startBit) {
                          label = selectedSignal!.isLittleEndian ? 'L' : 'M';
                        } else {
                          // Check if it's the other end
                          int endBit;
                          if (selectedSignal!.isLittleEndian) {
                            endBit = selectedSignal!.startBit + selectedSignal!.length - 1;
                            if (bitIndex == endBit) label = 'M';
                          } else {
                            // Motorola end bit (LSB)
                            int curr = selectedSignal!.startBit;
                            for (int i = 0; i < selectedSignal!.length - 1; i++) {
                              if (curr % 8 == 0) {
                                curr += 15;
                              } else {
                                curr -= 1;
                              }
                            }
                            if (bitIndex == curr) label = 'L';
                          }
                        }
                      }

                      if (label.isNotEmpty && bitValStr.isNotEmpty) {
                        label = '$bitValStr\n$label';
                      } else if (bitValStr.isNotEmpty) {
                        label = bitValStr;
                      }

                      return GestureDetector(
                        onTap: () {
                          if (onBitTapped != null) onBitTapped!(bitIndex);
                        },
                        child: Container(
                          width: clampedCellSize,
                          height: clampedCellSize,
                          margin: const EdgeInsets.only(right: 2.0),
                          decoration: BoxDecoration(
                            color: cellColor,
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected 
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(context, 'Selected', Theme.of(context).colorScheme.primaryContainer),
                const SizedBox(width: 16),
                _buildLegend(context, 'Other', Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5)),
                const SizedBox(width: 16),
                Text('L = LSB, M = MSB', style: Theme.of(context).textTheme.bodySmall),
              ],
            )
          ],
        );
      },
    );
  }

  Widget _buildLegend(BuildContext context, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
