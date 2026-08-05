import { useState, useEffect } from 'react';
import { Dialog, DialogTitle, DialogContent, DialogActions, Button, IconButton } from '@mui/material';
import { Close as CloseIcon } from '@mui/icons-material';
import { FullEditor } from './FullEditor';
import { LiteEditor } from './LiteEditor';

export const DbcEditorModal = ({ api, updateToolbar }: { api: any, updateToolbar: () => void }) => {
    const [open, setOpen] = useState(false);
    const [mode, setMode] = useState<'full' | 'lite'>('full');
    const [liteFrameId, setLiteFrameId] = useState<number | null>(null);

    const [dbState, setDbState] = useState<any>(null);
    const [originalDbState, setOriginalDbState] = useState<any>(null);
    // const [filePath, setFilePath] = useState<string | null>(null);

    useEffect(() => {
        const handleOpenFull = async () => {
            const res = await api.call_service('dbc.get_state');
            if (res && res.success) {
                setDbState(res.data);
                setOriginalDbState(JSON.parse(JSON.stringify(res.data)));
                // setFilePath(res.file_path);
                setMode('full');
                setOpen(true);
            }
        };

        const handleOpenLite = async (e: any) => {
            let res = await api.call_service('dbc.get_state');
            
            if (!res || !res.success) {
                // If no DBC is loaded, create a new one silently
                await api.call_service('dbc.new_file');
                res = await api.call_service('dbc.get_state');
            }

            if (res && res.success) {
                let state = res.data;
                const frameId = e.detail.frameId;
                const dlc = e.detail.dlc || 8;
                
                // If message doesn't exist, create it
                if (!state.messages.find((m: any) => m.frame_id === frameId)) {
                    state.messages.push({
                        frame_id: frameId,
                        name: `Message_0x${frameId.toString(16).toUpperCase()}`,
                        length: dlc,
                        senders: ['Vector__XXX'],
                        signals: [],
                        is_extended_frame: frameId > 0x7FF,
                        comment: ''
                    });
                    
                    if (!state.nodes.find((n:any) => n.name === 'Vector__XXX')) {
                        state.nodes.push({ name: 'Vector__XXX', comment: '' });
                    }
                }

                setDbState(state);
                setOriginalDbState(JSON.parse(JSON.stringify(state)));
                setLiteFrameId(frameId);
                setMode('lite');
                setOpen(true);
            }
        };

        window.addEventListener('openDbcEditor', handleOpenFull);
        window.addEventListener('openDbcLiteEditor', handleOpenLite);
        
        return () => {
            window.removeEventListener('openDbcEditor', handleOpenFull);
            window.removeEventListener('openDbcLiteEditor', handleOpenLite);
        };
    }, [api]);

    const isDirty = () => {
        return JSON.stringify(dbState) !== JSON.stringify(originalDbState);
    };

    const handleClose = () => {
        if (isDirty()) {
            if (!window.confirm("You have unsaved changes. Are you sure you want to cancel and lose your work?")) {
                return;
            }
        }
        setOpen(false);
    };

    const handleSave = async () => {
        try {
            const res = await api.call_service('dbc.save_state', dbState);
            if (res && res.success) {
                setOpen(false);
                updateToolbar();
                window.dispatchEvent(new CustomEvent('dbcLoaded'));
            } else {
                alert("Failed to save: " + res.error);
            }
        } catch (e) {
            console.error(e);
            alert("Error saving.");
        }
    };

    const handleSaveAs = async () => {
        // Here we could prompt for a file path, but assuming we can pass path=None 
        // to backend and have it request_file if needed?
        // Actually, cantools doesn't have a UI prompt in save_state.
        // For now, let's just trigger save. (Would need file-saver dialog in actual desktop app).
        alert("Save As not fully implemented. Saving normally.");
        handleSave();
    };

    if (!open || !dbState) return null;

    const dirty = isDirty();

    return (
        <Dialog 
            open={open} 
            fullScreen={mode === 'full'}
            maxWidth="lg"
            fullWidth={mode === 'lite'}
            onClose={(_event, reason) => {
                if (reason === 'escapeKeyDown') return;
                if (reason !== 'backdropClick') {
                    handleClose();
                } else if (mode === 'lite') {
                    // Lite editor closes on backdrop click if confirmed
                    handleClose();
                }
            }}
            slotProps={{
                paper: {
                    sx: { 
                        bgcolor: 'background.default',
                        display: 'flex',
                        flexDirection: 'column',
                        overflow: 'hidden' // We will handle scroll internally
                    }
                }
            }}
        >
            <DialogTitle sx={{ m: 0, p: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                {mode === 'full' ? 'DBC Editor' : 'Edit Frame'}{dirty ? ' *' : ''}
                <IconButton onClick={handleClose} size="small">
                    <CloseIcon />
                </IconButton>
            </DialogTitle>
            
            <DialogContent dividers sx={{ p: 0, flexGrow: 1, display: 'flex', overflow: 'hidden' }}>
                {mode === 'full' ? (
                    <FullEditor dbState={dbState} setDbState={setDbState} />
                ) : (
                    <LiteEditor dbState={dbState} setDbState={setDbState} frameId={liteFrameId} />
                )}
            </DialogContent>
            
            <DialogActions sx={{ p: 2, bgcolor: 'background.paper' }}>
                <Button onClick={handleClose} variant={dirty ? "outlined" : "contained"}>
                    {dirty ? "Cancel" : "Close"}
                </Button>
                {dirty && mode === 'full' && (
                    <Button onClick={handleSaveAs} variant="outlined">
                        Save As...
                    </Button>
                )}
                {dirty && (
                    <Button onClick={handleSave} variant="contained" color="primary">
                        Save
                    </Button>
                )}
            </DialogActions>
        </Dialog>
    );
};
