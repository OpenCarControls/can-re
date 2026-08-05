import { useState } from 'react';
import { Box, TextField, IconButton, List, ListItem, ListItemButton, ListItemText, Tooltip, Button } from '@mui/material';
import { Add as AddIcon } from '@mui/icons-material';
import { Delete as DeleteIcon } from '@mui/icons-material';
import { Edit as EditIcon } from '@mui/icons-material';

export const NodesColumn = ({ dbState, setDbState, selectedNodes, setSelectedNodes }: any) => {
    const [newNodeName, setNewNodeName] = useState('');
    const [editingNode, setEditingNode] = useState<string | null>(null);

    const nodes = dbState.nodes || [];
    const hasVectorXXX = nodes.find((n: any) => n.name === 'Vector__XXX');
    
    // Ensure Vector__XXX exists in view (even if we don't save it later if empty)
    const displayNodes = hasVectorXXX ? nodes : [{ name: 'Vector__XXX', comment: 'Default for unknown nodes' }, ...nodes];

    const handleAddNode = () => {
        if (!newNodeName.trim()) return;
        const newNodes = [...nodes, { name: newNodeName.trim(), comment: '' }];
        setDbState({ ...dbState, nodes: newNodes });
        setNewNodeName('');
    };

    const handleRename = (oldName: string, newName: string) => {
        if (!newName.trim() || oldName === newName) {
            setEditingNode(null);
            return;
        }
        
        // Update node name
        const newNodes = dbState.nodes.map((n: any) => n.name === oldName ? { ...n, name: newName.trim() } : n);
        
        // Update message senders
        const newMessages = dbState.messages.map((m: any) => {
            if (m.senders && m.senders.includes(oldName)) {
                return { ...m, senders: m.senders.map((s: string) => s === oldName ? newName.trim() : s) };
            }
            return m;
        });

        // Update signal receivers
        const newMessagesWithSignalRx = newMessages.map((m: any) => {
            return {
                ...m,
                signals: m.signals.map((sig: any) => {
                    if (sig.receivers && sig.receivers.includes(oldName)) {
                        return { ...sig, receivers: sig.receivers.map((r: string) => r === oldName ? newName.trim() : r) };
                    }
                    return sig;
                })
            };
        });

        setDbState({ ...dbState, nodes: newNodes, messages: newMessagesWithSignalRx });
        setEditingNode(null);
        if (selectedNodes.includes(oldName)) {
            setSelectedNodes(selectedNodes.map((n: string) => n === oldName ? newName.trim() : n));
        }
    };

    const handleDelete = (names: string[]) => {
        if (!window.confirm(`Delete ${names.length} node(s)? Messages will be moved to Vector__XXX.`)) return;
        
        const newNodes = dbState.nodes.filter((n: any) => !names.includes(n.name));
        const newMessages = dbState.messages.map((m: any) => {
            if (m.senders && m.senders.some((s: string) => names.includes(s))) {
                // Move to Vector__XXX
                return { ...m, senders: ['Vector__XXX'] };
            }
            return m;
        });

        setDbState({ ...dbState, nodes: newNodes, messages: newMessages });
        setSelectedNodes(selectedNodes.filter((n: string) => !names.includes(n)));
    };

    const toggleSelection = (name: string) => {
        if (selectedNodes.includes(name)) {
            setSelectedNodes(selectedNodes.filter((n: string) => n !== name));
        } else {
            setSelectedNodes([...selectedNodes, name]);
        }
    };

    const isMultiSelect = selectedNodes.length > 1;

    return (
        <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
            <Box sx={{ p: 1, borderBottom: 1, borderColor: 'divider', bgcolor: 'background.default' }}>
                {isMultiSelect ? (
                    <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                        <Button size="small" onClick={() => setSelectedNodes([])}>Unselect All</Button>
                        <Button size="small" color="error" onClick={() => handleDelete(selectedNodes)}>Delete Selected</Button>
                    </Box>
                ) : (
                    <Box sx={{ display: 'flex' }}>
                        <TextField 
                            size="small" 
                            variant="outlined" 
                            placeholder="Add Node..." 
                            value={newNodeName} 
                            onChange={e => setNewNodeName(e.target.value)} 
                            onKeyDown={e => e.key === 'Enter' && handleAddNode()}
                            fullWidth
                            sx={{ '& .MuiInputBase-root': { fontSize: '0.875rem', height: 32 } }}
                        />
                        <IconButton size="small" onClick={handleAddNode} color="primary" sx={{ ml: 1 }}>
                            <AddIcon fontSize="small" />
                        </IconButton>
                    </Box>
                )}
            </Box>

            <List sx={{ flexGrow: 1, overflow: 'auto', p: 0 }} dense>
                {displayNodes.map((node: any) => (
                    <ListItem 
                        key={node.name} 
                        disablePadding 
                        secondaryAction={
                            !isMultiSelect && selectedNodes.includes(node.name) && node.name !== 'Vector__XXX' && (
                                <Box>
                                    <IconButton size="small" onClick={() => setEditingNode(node.name)}>
                                        <EditIcon fontSize="small" />
                                    </IconButton>
                                    <IconButton size="small" edge="end" color="error" onClick={() => handleDelete([node.name])}>
                                        <DeleteIcon fontSize="small" />
                                    </IconButton>
                                </Box>
                            )
                        }
                    >
                        <ListItemButton 
                            selected={selectedNodes.includes(node.name)}
                            onClick={(e) => {
                                if (e.ctrlKey || e.metaKey) {
                                    toggleSelection(node.name);
                                } else {
                                    setSelectedNodes([node.name]);
                                }
                            }}
                        >
                            {editingNode === node.name ? (
                                <TextField 
                                    size="small"
                                    autoFocus
                                    defaultValue={node.name}
                                    onBlur={(e) => handleRename(node.name, e.target.value)}
                                    onKeyDown={(e) => {
                                        if (e.key === 'Enter') handleRename(node.name, (e.target as HTMLInputElement).value);
                                        if (e.key === 'Escape') setEditingNode(null);
                                    }}
                                    sx={{ '& .MuiInputBase-root': { fontSize: '0.875rem', height: 24 } }}
                                />
                            ) : (
                                <Tooltip title={node.name === 'Vector__XXX' ? 'Default for unknown nodes' : ''} placement="right">
                                    <ListItemText 
                                        primary={node.name} 
                                        slotProps={{ primary: { variant: 'body2', sx: { fontWeight: node.name === 'Vector__XXX' ? 'bold' : 'normal' } } }}
                                    />
                                </Tooltip>
                            )}
                        </ListItemButton>
                    </ListItem>
                ))}
            </List>

            {!isMultiSelect && selectedNodes.length === 1 && (
                <Box sx={{ p: 1, borderTop: 1, borderColor: 'divider' }}>
                    <TextField 
                        label="Node Comment"
                        size="small"
                        multiline
                        rows={2}
                        fullWidth
                        value={dbState.nodes.find((n: any) => n.name === selectedNodes[0])?.comment || ''}
                        onChange={(e) => {
                            const newNodes = dbState.nodes.map((n: any) => 
                                n.name === selectedNodes[0] ? { ...n, comment: e.target.value } : n
                            );
                            setDbState({ ...dbState, nodes: newNodes });
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
