import { useState, useEffect } from 'react';
import { Box, Typography, Divider, Button } from '@mui/material';
import { Edit as EditIcon } from '@mui/icons-material';

export const FrameDetails = () => {
  const [frame, setFrame] = useState<any>(null);

  useEffect(() => {
    const handler = (e: any) => {
      setFrame(e.detail);
    };
    window.addEventListener('frameSelected', handler);
    return () => window.removeEventListener('frameSelected', handler);
  }, []);

  if (!frame) {
    return (
      <Box sx={{ p: 2, height: '100%', overflow: 'auto', bgcolor: 'background.paper' }}>
        <Typography variant="body2" color="textSecondary">
          Select a CAN frame to view details.
        </Typography>
      </Box>
    );
  }

  const signals = frame.decoded && typeof frame.decoded === 'object' ? frame.decoded : null;
  const idHex = frame.id.toString(16).toUpperCase().padStart(frame.is_extended_id ? 8 : 3, '0');


  return (
    <Box sx={{ p: 2, height: '100%', overflow: 'auto', bgcolor: 'background.paper', position: 'relative' }}>
      <Button 
        variant="outlined" 
        size="small" 
        startIcon={<EditIcon />} 
        sx={{ position: 'absolute', top: 16, right: 16 }}
        onClick={() => {
          window.dispatchEvent(new CustomEvent('openDbcLiteEditor', { detail: { frameId: frame.id, dlc: frame.dlc } }));
        }}
      >
        Edit DBC
      </Button>

      {signals || (frame.decoded && typeof frame.decoded === 'string') ? (
        <Box sx={{ mb: 3 }}>
          <Typography variant="subtitle2" gutterBottom color="primary">
            Parsed Signals
          </Typography>
          <Divider sx={{ mb: 1 }} />
          {signals ? (
            <Box>
              {Object.entries(signals).map(([key, value]) => (
                <Box key={key} sx={{ mb: 1, display: 'flex', justifyContent: 'space-between' }}>
                  <Typography variant="body2" fontWeight="bold">{key}:</Typography>
                  <Typography variant="body2">{String(value)}</Typography>
                </Box>
              ))}
            </Box>
          ) : (
            <Typography variant="body2">
              {String(frame.decoded)}
            </Typography>
          )}
        </Box>
      ) : null}

      <Box>
        <Typography variant="subtitle2" gutterBottom color="textSecondary">
          Raw Frame Data
        </Typography>
        <Divider sx={{ mb: 1 }} />
        <Box sx={{ mb: 1, display: 'flex', justifyContent: 'space-between' }}>
          <Typography variant="body2" fontWeight="bold">ID:</Typography>
          <Typography variant="body2" fontFamily="monospace">0x{idHex}</Typography>
        </Box>
        <Box sx={{ mb: 1, display: 'flex', justifyContent: 'space-between' }}>
          <Typography variant="body2" fontWeight="bold">Timestamp:</Typography>
          <Typography variant="body2" fontFamily="monospace">{frame.timestamp.toFixed(6)}</Typography>
        </Box>
        <Box sx={{ mb: 1, display: 'flex', justifyContent: 'space-between' }}>
          <Typography variant="body2" fontWeight="bold">DLC:</Typography>
          <Typography variant="body2" fontFamily="monospace">{frame.dlc}</Typography>
        </Box>
        <Box sx={{ mt: 2 }}>
          <Typography variant="body2" fontWeight="bold" gutterBottom>Data (Hex & ASCII):</Typography>
          <Box sx={{ border: 1, borderColor: 'divider', borderRadius: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            {/* Header Row */}
            <Box sx={{ display: 'flex', bgcolor: 'action.hover', borderBottom: 1, borderColor: 'divider' }}>
              {Array.from({ length: Math.max(frame.data.length, 8) }).map((_, i) => (
                <Box key={`h-${i}`} sx={{ flex: 1, p: 0.5, textAlign: 'center', borderRight: i < Math.max(frame.data.length, 8) - 1 ? 1 : 0, borderColor: 'divider' }}>
                  <Typography variant="caption" color="textSecondary" fontFamily="monospace">
                    {i.toString(16).toUpperCase().padStart(2, '0')}
                  </Typography>
                </Box>
              ))}
            </Box>
            {/* Data Row */}
            <Box sx={{ display: 'flex' }}>
              {Array.from({ length: Math.max(frame.data.length, 8) }).map((_, i) => {
                const b = frame.data[i];
                const hasData = b !== undefined;
                return (
                  <Box key={`d-${i}`} sx={{ flex: 1, p: 1, textAlign: 'center', borderRight: i < Math.max(frame.data.length, 8) - 1 ? 1 : 0, borderColor: 'divider', bgcolor: hasData ? 'transparent' : 'action.disabledBackground' }}>
                    <Typography variant="body2" fontFamily="monospace" color={hasData ? 'textPrimary' : 'textSecondary'}>
                      {hasData ? b.toString(16).toUpperCase().padStart(2, '0') : '--'}
                    </Typography>
                  </Box>
                );
              })}
            </Box>
            {/* ASCII Row */}
            <Box sx={{ display: 'flex', borderTop: 1, borderColor: 'divider', bgcolor: 'background.default' }}>
              {Array.from({ length: Math.max(frame.data.length, 8) }).map((_, i) => {
                const b = frame.data[i];
                const hasData = b !== undefined;
                const char = hasData && b >= 32 && b <= 126 ? String.fromCharCode(b) : '.';
                return (
                  <Box key={`a-${i}`} sx={{ flex: 1, p: 0.5, textAlign: 'center', borderRight: i < Math.max(frame.data.length, 8) - 1 ? 1 : 0, borderColor: 'divider' }}>
                    <Typography variant="caption" fontFamily="monospace" color={hasData ? 'textSecondary' : 'action.disabled'}>
                      {hasData ? char : ''}
                    </Typography>
                  </Box>
                );
              })}
            </Box>
          </Box>
        </Box>
      </Box>
    </Box>
  );
};
