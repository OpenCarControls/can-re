import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Box, Typography, Checkbox, FormControlLabel, IconButton, Menu, MenuItem, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Toolbar as MuiToolbar } from '@mui/material';
import { TableVirtuoso } from 'react-virtuoso';
import type { TableComponents } from 'react-virtuoso';
import ViewColumnIcon from '@mui/icons-material/ViewColumn';
import SwapVertIcon from '@mui/icons-material/SwapVert';
import { getApi } from '../api';

const CHUNK_SIZE = 500;

interface CanMessage {
  timestamp: number;
  id: number;
  dlc: number;
  data: number[];
  is_extended_id: boolean;
  decoded: {
    name: string;
    signals: Record<string, number>;
  } | null;
}

const VirtuosoTableComponents: TableComponents<CanMessage> = {
  Scroller: React.forwardRef<HTMLDivElement>((props, ref) => <TableContainer {...props} ref={ref} />),
  Table: (props: any) => <Table {...props} sx={{ borderCollapse: 'separate', tableLayout: 'fixed' }} size="small" />,
  TableHead,
  TableRow: ({ item: _item, ...props }: any) => <TableRow {...props} hover sx={{ cursor: 'pointer', '&:last-child td, &:last-child th': { border: 0 } }} />,
  TableBody: React.forwardRef<HTMLTableSectionElement>((props, ref) => <TableBody {...props} ref={ref} />),
};

export const LogViewer = () => {
  const [totalCount, setTotalCount] = useState(0);
  const [reverseSort, setReverseSort] = useState(false);
  const [cache, setCache] = useState<Record<number, CanMessage[]>>({});
  const fetchingChunks = useRef<Set<number>>(new Set());

  const [columns, setColumns] = useState([
    { id: 'timestamp', label: 'Timestamp', visible: true },
    { id: 'id', label: 'ID (Hex)', visible: true },
    { id: 'dlc', label: 'DLC', visible: true },
    { id: 'data', label: 'Data', visible: true },
    { id: 'decoded_name', label: 'Message Name', visible: true },
    { id: 'decoded_signals', label: 'Signals', visible: true }
  ]);

  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);

  useEffect(() => {
    const handleLogLoaded = (e: any) => {
      setTotalCount(e.detail.count);
      setCache({});
      fetchingChunks.current.clear();
    };
    
    const handleDbcLoaded = () => {
      // Clear cache so it fetches decoded values again
      setCache({});
      fetchingChunks.current.clear();
    };

    window.addEventListener('logLoaded', handleLogLoaded);
    window.addEventListener('dbcLoaded', handleDbcLoaded);
    return () => {
      window.removeEventListener('logLoaded', handleLogLoaded);
      window.removeEventListener('dbcLoaded', handleDbcLoaded);
    };
  }, []);

  const fetchChunk = useCallback(async (chunkIndex: number, rev: boolean) => {
    if (fetchingChunks.current.has(chunkIndex)) return;
    fetchingChunks.current.add(chunkIndex);

    const start = chunkIndex * CHUNK_SIZE;
    try {
      const msgs = await getApi().get_log_chunk(start, CHUNK_SIZE, rev);
      setCache(prev => ({ ...prev, [chunkIndex]: msgs }));
    } catch (e) {
      console.error("Failed to fetch chunk", e);
    }
    fetchingChunks.current.delete(chunkIndex);
  }, []);

  // When reverse changes, clear cache
  useEffect(() => {
    setCache({});
    fetchingChunks.current.clear();
  }, [reverseSort]);

  const renderRow = (index: number) => {
    const chunkIndex = Math.floor(index / CHUNK_SIZE);
    const chunkData = cache[chunkIndex];
    
    if (!chunkData) {
      fetchChunk(chunkIndex, reverseSort);
      return <Box sx={{ p: 1 }}><Typography variant="body2" color="textSecondary">Loading...</Typography></Box>;
    }

    const itemIndex = index % CHUNK_SIZE;
    const item = chunkData[itemIndex];
    
    if (!item) {
      return <Box sx={{ p: 1 }}><Typography variant="body2" color="textSecondary">End</Typography></Box>;
    }

    // Format data
    const idHex = item.id.toString(16).toUpperCase().padStart(item.is_extended_id ? 8 : 3, '0');
    const dataHex = item.data.map(b => b.toString(16).toUpperCase().padStart(2, '0')).join(' ');
    
    let signalsStr = '';
    if (item.decoded) {
      signalsStr = Object.entries(item.decoded.signals).map(([k, v]) => `${k}: ${v}`).join(', ');
    }

    const rowData: Record<string, string> = {
      timestamp: item.timestamp.toFixed(6),
      id: `0x${idHex}`,
      dlc: item.dlc.toString(),
      data: dataHex,
      decoded_name: item.decoded?.name || '-',
      decoded_signals: signalsStr || '-'
    };

    return (
      <React.Fragment>
        {columns.filter(c => c.visible).map(col => (
          <TableCell key={col.id} sx={{ p: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: '0.8rem', color: col.id.startsWith('decoded') ? '#4db8ff' : 'text.primary' }}>
              {rowData[col.id]}
            </Typography>
          </TableCell>
        ))}
      </React.Fragment>
    );
  };

  const fixedHeaderContent = () => (
    <TableRow sx={{ bgcolor: 'background.paper' }}>
      {columns.filter(c => c.visible).map(col => (
        <TableCell key={col.id} sx={{ p: 1, fontWeight: 'bold' }}>
          {col.label}
        </TableCell>
      ))}
    </TableRow>
  );

  const toggleColumn = (id: string) => {
    setColumns(cols => cols.map(c => c.id === id ? { ...c, visible: !c.visible } : c));
  };

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%', bgcolor: 'background.default' }}>
      {/* Controls Toolbar */}
      <MuiToolbar variant="dense" sx={{ minHeight: '36px !important', borderBottom: 1, borderColor: 'divider', justifyContent: 'flex-end', px: 1 }}>
        <IconButton size="small" onClick={() => setReverseSort(r => !r)} title="Reverse Sort">
          <SwapVertIcon fontSize="small" color={reverseSort ? "primary" : "inherit"} />
        </IconButton>
        <IconButton size="small" onClick={(e) => setAnchorEl(e.currentTarget)} title="Columns">
          <ViewColumnIcon fontSize="small" />
        </IconButton>
      </MuiToolbar>

      {/* Table */}
      <Box sx={{ flexGrow: 1 }}>
        {totalCount > 0 ? (
          <TableVirtuoso
            style={{ height: '100%' }}
            totalCount={totalCount}
            components={VirtuosoTableComponents}
            fixedHeaderContent={fixedHeaderContent}
            itemContent={renderRow}
            overscan={200}
          />
        ) : (
          <Box sx={{ display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center' }}>
            <Typography color="textSecondary">No CAN log loaded.</Typography>
          </Box>
        )}
      </Box>

      {/* Column Menu */}
      <Menu anchorEl={anchorEl} open={Boolean(anchorEl)} onClose={() => setAnchorEl(null)}>
        {columns.map(col => (
          <MenuItem key={col.id} onClick={() => toggleColumn(col.id)}>
            <FormControlLabel
              control={<Checkbox checked={col.visible} size="small" />}
              label={<Typography variant="body2">{col.label}</Typography>}
            />
          </MenuItem>
        ))}
      </Menu>
    </Box>
  );
};
