import { useState } from 'react';
import { Box, TextField, IconButton, List, ListItem, ListItemButton, ListItemText, Checkbox, FormControlLabel, Typography } from '@mui/material';
import { Add as AddIcon } from '@mui/icons-material';
import { Delete as DeleteIcon } from '@mui/icons-material';
import { Edit as EditIcon } from '@mui/icons-material';

export const MessagesColumn = ({ dbState, setDbState, selectedNodes, selectedMessageId, setSelectedMessageId }: any) => {
    const [newMsgName, setNewMsgName] = useState('');
    const [newMsgIdHex, setNewMsgIdHex] = useState('');
    const [newMsgExtended, setNewMsgExtended] = useState(false);
    const [editingMsgId, setEditingMsgId] = useState<number | null>(null);

    const isMultiNode = selectedNodes.length > 1;
    const selectedNode = selectedNodes.length === 1 ? selectedNodes[0] : null;

    const messages = (dbState.messages || []).filter((m: any) => {
        if (!selectedNode) return false;
        return m.senders && m.senders.includes(selectedNode);
    });

    const handleAddMessage = () => {
        if (!newMsgName.trim() || !selectedNode || !newMsgIdHex.trim()) return;
        
        const newId = parseInt(newMsgIdHex, 16);
        if (isNaN(newId)) return;

        const newMsg = {
            frame_id: newId,
            name: newMsgName.trim(),
            length: 8,
            senders: [selectedNode],
            signals: [],
            is_extended_frame: newMsgExtended,
            comment: ''
        };

        setDbState({ ...dbState, messages: [...dbState.messages, newMsg] });
        setNewMsgName('');
        setNewMsgIdHex('');
    };

    const handleIdChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const val = e.target.value.replace(/[^0-9a-fA-F]/g, '');
        setNewMsgIdHex(val);
        const num = parseInt(val, 16);
        if (!isNaN(num) && num > 0x7FF) {
            setNewMsgExtended(true);
        }
    };

    const handleRename = (id: number, newName: string) => {
        if (!newName.trim()) {
            setEditingMsgId(null);
            return;
        }
        const newMessages = dbState.messages.map((m: any) => m.frame_id === id ? { ...m, name: newName.trim() } : m);
        setDbState({ ...dbState, messages: newMessages });
        setEditingMsgId(null);
    };

    const handleDelete = (id: number) => {
        if (!window.confirm("Delete this message?")) return;
        const newMessages = dbState.messages.filter((m: any) => m.frame_id !== id);
        setDbState({ ...dbState, messages: newMessages });
        if (selectedMessageId === id) setSelectedMessageId(null);
    };

    if (isMultiNode) {
        return <Box sx={{ p: 2, color: 'text.secondary' }}>Multiple nodes selected.</Box>;
    }

    if (!selectedNode) {
        return <Box sx={{ p: 2, color: 'text.secondary' }}>Select a node to view messages.</Box>;
    }

    return (
        <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
            <Box sx={{ p: 1, borderBottom: 1, borderColor: 'divider', bgcolor: 'background.default', display: 'flex', flexDirection: 'column', gap: 1 }}>
                <Box sx={{ display: 'flex', gap: 1 }}>
                    <TextField 
                        size="small" 
                        variant="outlined" 
                        placeholder="ID (Hex)" 
                        value={newMsgIdHex} 
                        onChange={handleIdChange}
                        onKeyDown={e => e.key === 'Enter' && handleAddMessage()}
                        sx={{ width: '80px', '& .MuiInputBase-root': { fontSize: '0.875rem', height: 32 } }}
                    />
                    <TextField 
                        size="small" 
                        variant="outlined" 
                        placeholder="Add Message..." 
                        value={newMsgName} 
                        onChange={e => setNewMsgName(e.target.value)} 
                        onKeyDown={e => e.key === 'Enter' && handleAddMessage()}
                        fullWidth
                        sx={{ '& .MuiInputBase-root': { fontSize: '0.875rem', height: 32 } }}
                    />
                </Box>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <FormControlLabel
                        control={<Checkbox size="small" checked={newMsgExtended} onChange={(e) => setNewMsgExtended(e.target.checked)} sx={{ p: 0.5 }} />}
                        label={<Typography variant="caption">Extended</Typography>}
                        sx={{ m: 0 }}
                    />
                    <IconButton size="small" onClick={handleAddMessage} color="primary" disabled={!newMsgName.trim() || !newMsgIdHex.trim()}>
                        <AddIcon fontSize="small" />
                    </IconButton>
                </Box>
            </Box>

            <List sx={{ flexGrow: 1, overflow: 'auto', p: 0 }} dense>
                {messages.map((msg: any) => (
                    <ListItem 
                        key={msg.frame_id} 
                        disablePadding 
                        secondaryAction={
                            selectedMessageId === msg.frame_id && (
                                <Box>
                                    <IconButton size="small" onClick={() => setEditingMsgId(msg.frame_id)}>
                                        <EditIcon fontSize="small" />
                                    </IconButton>
                                    <IconButton size="small" edge="end" color="error" onClick={() => handleDelete(msg.frame_id)}>
                                        <DeleteIcon fontSize="small" />
                                    </IconButton>
                                </Box>
                            )
                        }
                    >
                        <ListItemButton 
                            selected={selectedMessageId === msg.frame_id}
                            onClick={() => setSelectedMessageId(msg.frame_id)}
                        >
                            {editingMsgId === msg.frame_id ? (
                                <TextField 
                                    size="small"
                                    autoFocus
                                    defaultValue={msg.name}
                                    onBlur={(e) => handleRename(msg.frame_id, e.target.value)}
                                    onKeyDown={(e) => {
                                        if (e.key === 'Enter') handleRename(msg.frame_id, (e.target as HTMLInputElement).value);
                                        if (e.key === 'Escape') setEditingMsgId(null);
                                    }}
                                    sx={{ '& .MuiInputBase-root': { fontSize: '0.875rem', height: 24 } }}
                                />
                            ) : (
                                <ListItemText 
                                    primary={msg.name} 
                                    secondary={`ID: 0x${msg.frame_id.toString(16).toUpperCase()} ${msg.is_extended_frame ? '(Ext)' : ''}`}
                                    slotProps={{
                                        primary: { variant: 'body2' },
                                        secondary: { variant: 'caption', sx: { fontFamily: 'monospace' } }
                                    }}
                                />
                            )}
                        </ListItemButton>
                    </ListItem>
                ))}
            </List>

            {selectedMessageId && (
                <Box sx={{ p: 1, borderTop: 1, borderColor: 'divider' }}>
                    <TextField 
                        label="Message Comment"
                        size="small"
                        multiline
                        rows={2}
                        fullWidth
                        value={dbState.messages.find((m: any) => m.frame_id === selectedMessageId)?.comment || ''}
                        onChange={(e) => {
                            const newMessages = dbState.messages.map((m: any) => 
                                m.frame_id === selectedMessageId ? { ...m, comment: e.target.value } : m
                            );
                            setDbState({ ...dbState, messages: newMessages });
                        }}
                        slotProps={{
                            inputLabel: { shrink: true, sx: { fontSize: '0.875rem' } },
                            input: { sx: { fontSize: '0.875rem' } }
                        }}
                    />
                </Box>
            )}
        </Box>
    );
};
