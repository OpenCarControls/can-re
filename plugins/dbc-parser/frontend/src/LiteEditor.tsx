
import { Box, FormControl, InputLabel, Select, MenuItem } from '@mui/material';
import { MessageDetails } from './MessageDetails';

export const LiteEditor = ({ dbState, setDbState, frameId }: any) => {
    
    // Find the message
    const message = dbState.messages.find((m: any) => m.frame_id === frameId);
    
    // Default node (if somehow missing senders)
    const currentSender = message && message.senders && message.senders.length > 0 ? message.senders[0] : 'Vector__XXX';

    const handleNodeChange = (newNode: string) => {
        if (!message) return;
        const newMessages = dbState.messages.map((m: any) => {
            if (m.frame_id === frameId) {
                return { ...m, senders: [newNode] };
            }
            return m;
        });
        setDbState({ ...dbState, messages: newMessages });
    };

    if (!message) {
        return <Box sx={{ p: 3, textAlign: 'center' }}>Message not found in loaded DBC.</Box>;
    }

    return (
        <Box sx={{ display: 'flex', flexDirection: 'column', width: '100%', height: '100%' }}>
            {/* Node Reassignment Dropdown */}
            <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider', bgcolor: 'background.paper' }}>
                <FormControl size="small" sx={{ minWidth: 200 }}>
                    <InputLabel>Assigned Node</InputLabel>
                    <Select
                        value={currentSender}
                        label="Assigned Node"
                        onChange={(e) => handleNodeChange(e.target.value)}
                    >
                        {dbState.nodes.map((n: any) => (
                            <MenuItem key={n.name} value={n.name}>{n.name}</MenuItem>
                        ))}
                        {/* Ensure Vector__XXX is available if not in list */}
                        {!dbState.nodes.find((n:any) => n.name === 'Vector__XXX') && (
                            <MenuItem value="Vector__XXX">Vector__XXX</MenuItem>
                        )}
                    </Select>
                </FormControl>
            </Box>

            {/* Reuse MessageDetails */}
            <Box sx={{ flexGrow: 1, overflow: 'hidden' }}>
                <MessageDetails 
                    dbState={dbState}
                    setDbState={setDbState}
                    messageId={frameId}
                />
            </Box>
        </Box>
    );
};
