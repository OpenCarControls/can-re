import { useState } from 'react';
import { Box, Typography, TextField, IconButton, Select, MenuItem, FormControl, InputLabel, Grid, FormControlLabel, Checkbox } from '@mui/material';
import { Add as AddIcon } from '@mui/icons-material';
import { Delete as DeleteIcon } from '@mui/icons-material';
import { SignalBitGrid } from './SignalBitGrid';

export const MessageDetails = ({ dbState, setDbState, messageId }: any) => {
    const [selectedSignalName, setSelectedSignalName] = useState<string | null>(null);

    const message = dbState.messages.find((m: any) => m.frame_id === messageId);
    if (!message) return null;

    const signals = message.signals || [];
    const selectedSignal = signals.find((s: any) => s.name === selectedSignalName);

    const updateMessage = (updatedMsg: any) => {
        const newMessages = dbState.messages.map((m: any) => m.frame_id === messageId ? updatedMsg : m);
        setDbState({ ...dbState, messages: newMessages });
    };

    const handleAddSignal = () => {
        const newSigName = `NewSignal_${signals.length + 1}`;
        const newSig = {
            name: newSigName,
            start: 0,
            length: 8,
            byte_order: 'little_endian',
            is_signed: false,
            scale: 1,
            offset: 0,
            minimum: null,
            maximum: null,
            unit: '',
            comment: ''
        };
        updateMessage({ ...message, signals: [...signals, newSig] });
        setSelectedSignalName(newSigName);
    };

    const updateSignal = (updatedSig: any) => {
        const newSignals = signals.map((s: any) => s.name === selectedSignalName ? updatedSig : s);
        
        // If we renamed the signal, update selection
        if (updatedSig.name !== selectedSignalName) {
            setSelectedSignalName(updatedSig.name);
        }
        
        updateMessage({ ...message, signals: newSignals });
    };

    const handleDeleteSignal = (name: string) => {
        if (!window.confirm("Delete this signal?")) return;
        updateMessage({ ...message, signals: signals.filter((s: any) => s.name !== name) });
        if (selectedSignalName === name) setSelectedSignalName(null);
    };

    return (
        <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
            {/* Message Header */}
            <Box sx={{ p: 2, bgcolor: 'background.default', borderBottom: 1, borderColor: 'divider' }}>
                <Typography variant="h6" gutterBottom>{message.name}</Typography>
                <Grid container spacing={2} sx={{ mb: 2 }}>
                    <Grid size={{ xs: 6 }}>
                        <TextField
                            label="Message ID (Hex)"
                            size="small"
                            fullWidth
                            value={message.frame_id.toString(16).toUpperCase()}
                            onChange={(e) => {
                                const clean = e.target.value.replace(/[^0-9a-fA-F]/g, '');
                                const val = clean ? parseInt(clean, 16) : 0;
                                updateMessage({ ...message, frame_id: val });
                            }}
                        />
                    </Grid>
                    <Grid size={{ xs: 6 }} sx={{ display: 'flex', alignItems: 'center' }}>
                        <FormControlLabel
                            control={
                                <Checkbox 
                                    size="small" 
                                    checked={message.is_extended_frame || false} 
                                    onChange={(e) => updateMessage({ ...message, is_extended_frame: e.target.checked })} 
                                />
                            }
                            label="Extended Frame"
                        />
                    </Grid>
                </Grid>
                <TextField 
                    label="Message Comment"
                    size="small"
                    multiline
                    rows={2}
                    fullWidth
                    value={message.comment || ''}
                    onChange={(e) => updateMessage({ ...message, comment: e.target.value })}
                    slotProps={{
                        inputLabel: { shrink: true, sx: { fontSize: '0.875rem' } },
                        input: { sx: { fontSize: '0.875rem' } }
                    }}
                />
            </Box>

            <Box sx={{ display: 'flex', flexGrow: 1, overflow: 'hidden' }}>
                {/* Signals List */}
                <Box sx={{ width: 200, borderRight: 1, borderColor: 'divider', display: 'flex', flexDirection: 'column' }}>
                    <Box sx={{ p: 1, borderBottom: 1, borderColor: 'divider', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <Typography variant="subtitle2">Signals</Typography>
                        <IconButton size="small" onClick={handleAddSignal} color="primary">
                            <AddIcon fontSize="small" />
                        </IconButton>
                    </Box>
                    <Box sx={{ flexGrow: 1, overflow: 'auto' }}>
                        {signals.map((sig: any) => (
                            <Box 
                                key={sig.name}
                                onClick={() => setSelectedSignalName(sig.name)}
                                sx={{ 
                                    p: 1, 
                                    cursor: 'pointer', 
                                    bgcolor: selectedSignalName === sig.name ? 'action.selected' : 'transparent',
                                    '&:hover': { bgcolor: 'action.hover' },
                                    display: 'flex',
                                    justifyContent: 'space-between',
                                    alignItems: 'center'
                                }}
                            >
                                <Typography variant="body2">{sig.name}</Typography>
                                {selectedSignalName === sig.name && (
                                    <IconButton size="small" color="error" onClick={(e) => { e.stopPropagation(); handleDeleteSignal(sig.name); }}>
                                        <DeleteIcon fontSize="small" />
                                    </IconButton>
                                )}
                            </Box>
                        ))}
                    </Box>
                </Box>

                {/* Signal Editor */}
                <Box sx={{ flexGrow: 1, p: 2, overflow: 'auto' }}>
                    {selectedSignal ? (
                        <Grid container spacing={2}>
                            <Grid size={{ xs: 12 }}>
                                <TextField 
                                    label="Signal Name"
                                    size="small"
                                    fullWidth
                                    value={selectedSignal.name}
                                    onChange={(e) => updateSignal({ ...selectedSignal, name: e.target.value })}
                                />
                            </Grid>
                            
                            <Grid size={{ xs: 12, md: 6 }}>
                                <SignalBitGrid 
                                    messageLength={message.length}
                                    signals={signals}
                                    selectedSignalName={selectedSignal.name}
                                    onBitClick={(bit: number) => updateSignal({ ...selectedSignal, start: bit })}
                                />
                            </Grid>

                            <Grid size={{ xs: 12, md: 6 }}>
                                <Grid container spacing={2}>
                                    <Grid size={{ xs: 6 }}>
                                        <TextField 
                                            label="Start Bit"
                                            type="number"
                                            size="small"
                                            fullWidth
                                            value={selectedSignal.start}
                                            onChange={(e) => updateSignal({ ...selectedSignal, start: parseInt(e.target.value) || 0 })}
                                        />
                                    </Grid>
                                    <Grid size={{ xs: 6 }}>
                                        <TextField 
                                            label="Length (bits)"
                                            type="number"
                                            size="small"
                                            fullWidth
                                            value={selectedSignal.length}
                                            onChange={(e) => updateSignal({ ...selectedSignal, length: parseInt(e.target.value) || 1 })}
                                        />
                                    </Grid>
                                    <Grid size={{ xs: 6 }}>
                                        <FormControl size="small" fullWidth>
                                            <InputLabel>Byte Order</InputLabel>
                                            <Select
                                                value={selectedSignal.byte_order}
                                                label="Byte Order"
                                                onChange={(e) => updateSignal({ ...selectedSignal, byte_order: e.target.value })}
                                            >
                                                <MenuItem value="little_endian">Intel (Little Endian)</MenuItem>
                                                <MenuItem value="big_endian">Motorola (Big Endian)</MenuItem>
                                            </Select>
                                        </FormControl>
                                    </Grid>
                                    <Grid size={{ xs: 6 }}>
                                        <FormControlLabel 
                                            control={<Checkbox size="small" checked={selectedSignal.is_signed} onChange={(e) => updateSignal({ ...selectedSignal, is_signed: e.target.checked })} />}
                                            label="Signed"
                                        />
                                    </Grid>
                                    <Grid size={{ xs: 6 }}>
                                        <TextField 
                                            label="Factor"
                                            type="number"
                                            size="small"
                                            fullWidth
                                            value={selectedSignal.scale}
                                            onChange={(e) => updateSignal({ ...selectedSignal, scale: parseFloat(e.target.value) || 1 })}
                                        />
                                    </Grid>
                                    <Grid size={{ xs: 6 }}>
                                        <TextField 
                                            label="Offset"
                                            type="number"
                                            size="small"
                                            fullWidth
                                            value={selectedSignal.offset}
                                            onChange={(e) => updateSignal({ ...selectedSignal, offset: parseFloat(e.target.value) || 0 })}
                                        />
                                    </Grid>
                                    <Grid size={{ xs: 6 }}>
                                        <TextField 
                                            label="Min"
                                            type="number"
                                            size="small"
                                            fullWidth
                                            value={selectedSignal.minimum ?? ''}
                                            onChange={(e) => updateSignal({ ...selectedSignal, minimum: e.target.value ? parseFloat(e.target.value) : null })}
                                        />
                                    </Grid>
                                    <Grid size={{ xs: 6 }}>
                                        <TextField 
                                            label="Max"
                                            type="number"
                                            size="small"
                                            fullWidth
                                            value={selectedSignal.maximum ?? ''}
                                            onChange={(e) => updateSignal({ ...selectedSignal, maximum: e.target.value ? parseFloat(e.target.value) : null })}
                                        />
                                    </Grid>
                                    <Grid size={{ xs: 12 }}>
                                        <TextField 
                                            label="Unit"
                                            size="small"
                                            fullWidth
                                            value={selectedSignal.unit || ''}
                                            onChange={(e) => updateSignal({ ...selectedSignal, unit: e.target.value })}
                                        />
                                    </Grid>
                                    <Grid size={{ xs: 12 }}>
                                        <TextField 
                                            label="Signal Comment"
                                            size="small"
                                            multiline
                                            rows={2}
                                            fullWidth
                                            value={selectedSignal.comment || ''}
                                            onChange={(e) => updateSignal({ ...selectedSignal, comment: e.target.value })}
                                        />
                                    </Grid>
                                </Grid>
                            </Grid>
                        </Grid>
                    ) : (
                        <Typography color="text.secondary">Select a signal to edit properties.</Typography>
                    )}
                </Box>
            </Box>
        </Box>
    );
};
