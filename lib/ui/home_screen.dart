import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../connections/csv_connection.dart';
import '../models/can_frame.dart';
import '../providers/frame_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  
  CsvConnection? _currentConnection;
  bool _isAutoScrolling = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_currentConnection == null || !_currentConnection!.isLive) return;
    
    // If the user scrolls down (offset > 10), disable auto-scroll
    if (_scrollController.offset > 10.0 && _isAutoScrolling) {
      setState(() {
        _isAutoScrolling = false;
      });
    } 
    // If the user scrolls back to the very top, re-enable auto-scroll
    else if (_scrollController.offset <= 10.0 && !_isAutoScrolling) {
      setState(() {
        _isAutoScrolling = true;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _currentConnection?.disconnect();
    super.dispose();
  }

  Future<void> _loadCsv() async {
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
        
        // Reset scroll position and state
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
        setState(() {
          _isAutoScrolling = true;
        });
        
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

  void _saveCsv() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save CSV not implemented yet.')),
    );
  }

  void _connectLive() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live source connection not implemented yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final frameState = ref.watch(frameProvider);
    final frames = frameState.filteredFrames;

    // Listen to frame updates to adjust scroll offset if locked
    ref.listen<FrameState>(frameProvider, (previous, next) {
      if (previous == null || previous.filteredFrames.isEmpty) return;
      if (_currentConnection == null || !_currentConnection!.isLive) return;
      
      final newFramesAdded = next.filteredFrames.length - previous.filteredFrames.length;
      if (newFramesAdded > 0 && !_isAutoScrolling) {
        if (_scrollController.hasClients) {
          // Push the scrollbar down by exactly the height of the new frames
          _scrollController.jumpTo(_scrollController.offset + (newFramesAdded * 32.0));
        }
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;
        
        return Scaffold(
          appBar: _buildControlBar(isDesktop, frameState),
          endDrawer: isDesktop ? null : const Drawer(child: _SidebarContent(isDrawer: true)),
          body: Row(
            children: [
              Expanded(
                child: _buildMainTableContent(frameState, frames),
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
        );
      },
    );
  }

  PreferredSizeWidget _buildControlBar(bool isDesktop, FrameState frameState) {
    
    return AppBar(
      title: Text(
        'OpenCarControls CAN RE',
        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
      ),
      scrolledUnderElevation: 0.0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: [
        if (frameState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        
        // Context Actions
        if (isDesktop) ...[
          TextButton.icon(
            onPressed: frameState.isLoading ? null : _loadCsv,
            icon: const Icon(Icons.folder_open),
            label: const Text('Load CSV'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: frameState.frames.isEmpty ? null : _saveCsv,
            icon: const Icon(Icons.save),
            label: const Text('Save CSV'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _connectLive,
            icon: const Icon(Icons.bolt),
            label: const Text('Connect Live'),
          ),
          const SizedBox(width: 16),
        ] else ...[
          // Mobile overflow menu
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'load') _loadCsv();
              if (value == 'save') _saveCsv();
              if (value == 'live') _connectLive();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'load', child: Text('Load CSV')),
              const PopupMenuItem(value: 'save', child: Text('Save CSV')),
              const PopupMenuItem(value: 'live', child: Text('Connect Live')),
            ],
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filters & Options',
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
          const SizedBox(width: 4),
        ]
      ],
    );
  }

  Widget _buildMainTableContent(FrameState frameState, List<CanFrame> frames) {

    return Stack(
      children: [
        frames.isEmpty
            ? Center(
                child: Text(
                  frameState.isLoading ? 'Parsing data, please wait...' : 'No frames to display. Connect to a live source or load a CSV.',
                  style: GoogleFonts.inter(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  // Minimum width for the table. If screen is smaller, enable horizontal scrolling
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
                          itemExtent: 32.0,
                          itemCount: frames.length,
                          itemBuilder: (context, index) {
                            // Reverse chronological: newest at top (index 0 is the last frame added)
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
              ),
              
        // Jump to Live Button
        if (!_isAutoScrolling && frames.isNotEmpty && (_currentConnection?.isLive ?? false))
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
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
              ),
            ),
          ),
      ],
    );
  }
}

/// The Sidebar component that displays filtering and display options.
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


// Shared layout configuration for the data grid columns.
// Flex values decide the proportional width of each column.
final Map<String, int> _colFlexConfig = {
  'Timestamp': 3,
  'ID': 2,
  'Ext': 1,
  'Dir': 1,
  'Bus': 1,
  'Len': 1,
  'Data': 6,
};

Widget _buildFlexCell(String text, int flex, {bool isHeader = false, bool isMono = false}) {
  return Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
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
        children: _colFlexConfig.entries
            .where((entry) => visibleColumns[entry.key] == true)
            .map((entry) => _buildFlexCell(entry.key, entry.value, isHeader: true))
            .toList(),
      ),
    );
  }
}

class _DataGridRow extends StatelessWidget {
  final CanFrame frame;
  final int index;
  final Map<String, bool> visibleColumns;

  const _DataGridRow({
    required this.frame,
    required this.index,
    required this.visibleColumns,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32.0,
      color: index.isEven ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: _colFlexConfig.entries
            .where((entry) => visibleColumns[entry.key] == true)
            .map((entry) {
              String text = '';
              bool isMono = false;
              switch (entry.key) {
                case 'Timestamp': text = frame.formattedTimestamp; break;
                case 'ID': text = '0x${frame.idHex}'; isMono = true; break;
                case 'Ext': text = frame.isExtended ? 'Yes' : 'No'; break;
                case 'Dir': text = frame.direction; break;
                case 'Bus': text = frame.bus.toString(); break;
                case 'Len': text = frame.length.toString(); break;
                case 'Data': text = frame.dataHex; isMono = true; break;
              }
              return _buildFlexCell(text, entry.value, isMono: isMono);
            }).toList(),
      ),
    );
  }
}
