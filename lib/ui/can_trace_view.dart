import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/can_frame.dart';
import '../models/dbc_model.dart';
import '../providers/dbc_provider.dart';
import '../providers/frame_provider.dart';
import '../providers/connection_provider.dart';
import '../utils/dbc_decoder.dart';
import 'widgets/dbc_lite_editor.dart';

class CanTraceView extends ConsumerStatefulWidget {
  const CanTraceView({super.key});

  @override
  ConsumerState<CanTraceView> createState() => _CanTraceViewState();
}

class _CanTraceViewState extends ConsumerState<CanTraceView> {
  final ScrollController _scrollController = ScrollController();
  bool _isAutoScrolling = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final connection = ref.read(connectionProvider);
    if (!connection.isLive) return;
    
    if (_scrollController.offset > 10.0 && _isAutoScrolling) {
      setState(() {
        _isAutoScrolling = false;
      });
    } else if (_scrollController.offset <= 10.0 && !_isAutoScrolling) {
      setState(() {
        _isAutoScrolling = true;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frameState = ref.watch(frameProvider);
    final frames = frameState.filteredFrames;
    final connection = ref.watch(connectionProvider);

    ref.listen<FrameState>(frameProvider, (previous, next) {
      if (previous == null || previous.filteredFrames.isEmpty) return;
      if (!connection.isLive) return;
      
      final newFramesAdded = next.filteredFrames.length - previous.filteredFrames.length;
      if (newFramesAdded > 0 && !_isAutoScrolling) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.offset + (newFramesAdded * 32.0));
        }
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;
        
        return Scaffold(
          endDrawer: isDesktop ? null : const Drawer(child: _SidebarContent(isDrawer: true)),
          appBar: isDesktop ? null : AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
            actions: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
          ),
          body: Row(
            children: [
              Expanded(
                child: _buildMainTableContent(frameState, frames, connection.isLive),
              ),
              if (isDesktop)
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Container(
                    width: 300,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: const _SidebarContent(),
                  ),
                ),
            ],
          ),
          floatingActionButton: (!_isAutoScrolling && frames.isNotEmpty && connection.isLive)
              ? FloatingActionButton.extended(
                  onPressed: () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text('Jump to Live'),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildMainTableContent(FrameState frameState, List<CanFrame> frames, bool isLive) {
    if (frames.isEmpty) {
      return Center(
        child: Text(
          frameState.isLoading ? 'Parsing data, please wait...' : 'No frames to display. Connect to a live source or load a CSV.',
          style: GoogleFonts.inter(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const minTableWidth = 800.0;
        final isScrollableHorizontally = constraints.maxWidth < minTableWidth;

        Widget tableBody = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DataGridHeaderRow(visibleColumns: frameState.visibleColumns),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemExtent: 56.0,
                itemCount: frames.length,
                itemBuilder: (context, index) {
                  final reversedIndex = frames.length - 1 - index;
                  return _DataGridRow(
                    frame: frames[reversedIndex],
                    index: reversedIndex,
                    visibleColumns: frameState.visibleColumns,
                  );
                },
              ),
            ),
          ],
        );

        if (isScrollableHorizontally) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: minTableWidth,
              child: tableBody,
            ),
          );
        }

        return tableBody;
      },
    );
  }
}

class _SidebarContent extends ConsumerStatefulWidget {
  final bool isDrawer;
  const _SidebarContent({this.isDrawer = false});

  @override
  ConsumerState<_SidebarContent> createState() => _SidebarContentState();
}

class _SidebarContentState extends ConsumerState<_SidebarContent> {
  final TextEditingController _busFilterController = TextEditingController();
  final TextEditingController _idFilterController = TextEditingController();

  @override
  void dispose() {
    _busFilterController.dispose();
    _idFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frameState = ref.watch(frameProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters & Options',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (widget.isDrawer)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text('Data Filtering', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: _busFilterController,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Bus',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_bus),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => ref.read(frameProvider.notifier).setFilterBus(val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _idFilterController,
                  decoration: const InputDecoration(
                    labelText: 'Filter by ID (Hex)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                    isDense: true,
                  ),
                  onChanged: (val) => ref.read(frameProvider.notifier).setFilterIdHex(val),
                ),
                const SizedBox(height: 32),
                Text('Visible Columns', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...frameState.visibleColumns.keys.map((col) {
                  return SwitchListTile(
                    title: Text(col),
                    value: frameState.visibleColumns[col] ?? true,
                    onChanged: (val) => ref.read(frameProvider.notifier).toggleColumn(col),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final Map<String, int> _colFlexConfig = {
  'Timestamp': 3,
  'ID': 2,
  'Ext': 1,
  'Dir': 1,
  'Bus': 1,
  'Len': 1,
  'Data': 8,
};

Widget _buildFlexCell(int flex, {String? text, Widget? child, bool isHeader = false, bool isMono = false}) {
  return Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      alignment: Alignment.centerLeft,
      child: child ?? Text(
        text ?? '',
        style: isHeader
            ? GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)
            : (isMono ? GoogleFonts.robotoMono(fontSize: 13) : GoogleFonts.inter(fontSize: 13)),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class _DataGridHeaderRow extends StatelessWidget {
  final Map<String, bool> visibleColumns;

  const _DataGridHeaderRow({required this.visibleColumns});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          ..._colFlexConfig.entries
              .where((entry) => visibleColumns[entry.key] == true)
              .map((entry) => _buildFlexCell(entry.value, text: entry.key, isHeader: true)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _DataGridRow extends ConsumerWidget {
  final CanFrame frame;
  final int index;
  final Map<String, bool> visibleColumns;

  const _DataGridRow({
    required this.frame,
    required this.index,
    required this.visibleColumns,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDbc = ref.watch(dbcProvider).activeDbc;
    DecodedMessage? decodedMsg;
    if (activeDbc != null) {
      decodedMsg = DbcDecoder.decode(activeDbc, frame);
    }

    return Container(
      color: index.isEven ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(vertical: 4.0), 
      child: Row(
        children: [
          ..._colFlexConfig.entries
              .where((entry) => visibleColumns[entry.key] == true)
              .map((entry) {
                if (entry.key == 'ID') {
                  if (decodedMsg != null) {
                    return _buildFlexCell(
                      entry.value,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(decodedMsg.message.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          Text('0x${frame.idHex}', style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    );
                  }
                  return _buildFlexCell(entry.value, text: '0x${frame.idHex}', isMono: true);
                }

                if (entry.key == 'Data') {
                  if (decodedMsg != null) {
                    return _buildFlexCell(
                      entry.value,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: decodedMsg.decodedSignals.map((ds) => Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  child: Text(
                                    '${ds.signal.name}: ${ds.formattedValue}',
                                    style: GoogleFonts.inter(fontSize: 10, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(frame.dataHex, style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    );
                  }
                  return _buildFlexCell(entry.value, text: frame.dataHex, isMono: true);
                }

                String text = '';
                bool isMono = false;
                switch (entry.key) {
                  case 'Timestamp': text = frame.formattedTimestamp; break;
                  case 'Ext': text = frame.isExtended ? 'Yes' : 'No'; break;
                  case 'Dir': text = frame.direction; break;
                  case 'Bus': text = frame.bus.toString(); break;
                  case 'Len': text = frame.length.toString(); break;
                }
                return _buildFlexCell(entry.value, text: text, isMono: isMono);
              }),
          SizedBox(
            width: 40,
            child: IconButton(
              iconSize: 16,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.edit),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    final isNarrow = MediaQuery.of(context).size.width < 600;
                    return FractionallySizedBox(
                      heightFactor: isNarrow ? 0.95 : 0.8,
                      child: DbcLiteEditor(frame: frame),
                    );
                  },
                );
              },
              tooltip: 'Edit DBC Signal',
            ),
          ),
        ],
      ),
    );
  }
}
