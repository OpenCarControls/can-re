import { Box, IconButton, Typography } from '@mui/material';
import MinimizeIcon from '@mui/icons-material/Minimize';
import CropSquareIcon from '@mui/icons-material/CropSquare';
import CloseIcon from '@mui/icons-material/Close';

export const Titlebar = () => {
  // Only render window controls if running in pywebview
  const isDesktop = !!window.pywebview;

  const handleMinimize = () => {
    window.pywebview?.api?.minimize_window();
  };

  const handleMaximize = () => {
    window.pywebview?.api?.maximize_window();
  };

  const handleClose = () => {
    window.pywebview?.api?.close_window();
  };

  return (
    <Box
      className="pywebview-drag-region"
      sx={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        height: 32,
        bgcolor: '#333333', // Dark titlebar typical of IDEs
        color: 'text.secondary',
        userSelect: 'none',
        WebkitUserSelect: 'none',
        flexShrink: 0,
        width: '100vw'
      }}
    >
      <Box sx={{ pl: 2, display: 'flex', alignItems: 'center' }}>
        <Typography variant="caption" sx={{ fontSize: '0.75rem', fontWeight: 500 }}>
          CAN RE
        </Typography>
      </Box>

      {isDesktop && (
        <Box sx={{ display: 'flex', height: '100%', WebkitAppRegion: 'no-drag' } as any}>
          <IconButton
            onClick={handleMinimize}
            size="small"
            sx={{ borderRadius: 0, width: 46, '&:hover': { bgcolor: 'rgba(255, 255, 255, 0.1)' } }}
            disableRipple
          >
            <MinimizeIcon sx={{ fontSize: 16, mb: 1 }} />
          </IconButton>
          <IconButton
            onClick={handleMaximize}
            size="small"
            sx={{ borderRadius: 0, width: 46, '&:hover': { bgcolor: 'rgba(255, 255, 255, 0.1)' } }}
            disableRipple
          >
            <CropSquareIcon sx={{ fontSize: 14 }} />
          </IconButton>
          <IconButton
            onClick={handleClose}
            size="small"
            sx={{ borderRadius: 0, width: 46, '&:hover': { bgcolor: '#e81123', color: 'white' } }}
            disableRipple
          >
            <CloseIcon sx={{ fontSize: 16 }} />
          </IconButton>
        </Box>
      )}
    </Box>
  );
};
