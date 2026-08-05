import { useState } from 'react';
import { Box } from '@mui/material';
import { NodesColumn } from './NodesColumn';
import { MessagesColumn } from './MessagesColumn';
import { MessageDetails } from './MessageDetails';

export const FullEditor = ({ dbState, setDbState }: { dbState: any, setDbState: any }) => {
    const [selectedNodes, setSelectedNodes] = useState<string[]>([]);
    const [selectedMessageId, setSelectedMessageId] = useState<number | null>(null);

    return (
        <Box sx={{ display: 'flex', width: '100%', height: '100%' }}>
            {/* Column 1: Nodes */}
            <Box sx={{ width: '25%', minWidth: 200, display: 'flex', flexDirection: 'column', borderRight: 1, borderColor: 'divider' }}>
                <NodesColumn 
                    dbState={dbState} 
                    setDbState={setDbState} 
                    selectedNodes={selectedNodes}
                    setSelectedNodes={setSelectedNodes}
                />
            </Box>

            {/* Column 2: Messages */}
            <Box sx={{ width: '30%', minWidth: 250, display: 'flex', flexDirection: 'column', borderRight: 1, borderColor: 'divider' }}>
                <MessagesColumn 
                    dbState={dbState} 
                    setDbState={setDbState}
                    selectedNodes={selectedNodes}
                    selectedMessageId={selectedMessageId}
                    setSelectedMessageId={setSelectedMessageId}
                />
            </Box>

            {/* Column 3: Message Details / Signals */}
            <Box sx={{ flexGrow: 1, display: 'flex', flexDirection: 'column', overflow: 'auto' }}>
                {selectedMessageId !== null ? (
                    <MessageDetails 
                        dbState={dbState}
                        setDbState={setDbState}
                        messageId={selectedMessageId}
                    />
                ) : (
                    <Box sx={{ p: 3, color: 'text.secondary', textAlign: 'center' }}>
                        Select a message to edit its details and signals.
                    </Box>
                )}
            </Box>
        </Box>
    );
};
