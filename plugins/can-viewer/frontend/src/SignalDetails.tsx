import { Box, Typography } from '@mui/material';


export const SignalDetails = () => {
  return (
    <Box sx={{ p: 2, height: '100%', overflow: 'auto', bgcolor: 'background.paper' }}>
      <Typography variant="body2" color="textSecondary">
        Select a CAN frame to view decoded signal details.
      </Typography>
    </Box>
  );
};
