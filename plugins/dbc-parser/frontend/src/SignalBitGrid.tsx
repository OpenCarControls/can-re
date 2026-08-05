
import { Box, Typography } from '@mui/material';

export const SignalBitGrid = ({ 
    messageLength, // in bytes
    signals, 
    selectedSignalName, 
    onBitClick 
}: any) => {
    // A 8x8 grid of bits. For CAN, max 64 bits (8 bytes).
    // Let's support up to 64 bytes (CAN FD) eventually, but for now max is 8 bytes.
    // SavvyCAN style: 8 columns (bit 7 to 0).
    const bytes = Math.min(messageLength, 8); // Display up to 8 bytes for now
    
    // Helper to see if a bit is within a signal's span
    const getSignalAtBit = (bitIndex: number) => {
        for (const sig of signals) {
            // Very simplified: doesn't fully handle Motorola vs Intel spanning correctly for visual grid yet
            // To do this perfectly, you need complex logic based on byte_order
            // For now, let's just do a basic highlight if it falls in range (assuming Intel)
            
            if (sig.byte_order === 'little_endian') {
                // Intel: start bit is LSB. 
                const endBit = sig.start + sig.length - 1;
                if (bitIndex >= sig.start && bitIndex <= endBit) return sig;
            } else {
                // Motorola: start bit is MSB.
                // Calculating the span of motorola is tricky in a linear bit array.
                // Usually it goes backwards. We will approximate.
                // For a 8-bit signal starting at 7: it occupies 0-7.
                // const startByte = Math.floor(sig.start / 8);
                // const bitInByte = sig.start % 8;
                // Just highlight the start bit for now if complex.
                if (bitIndex === sig.start) return sig;
            }
        }
        return null;
    };

    return (
        <Box sx={{ border: 1, borderColor: 'divider', display: 'flex', flexDirection: 'column', width: 'fit-content', userSelect: 'none' }}>
            {/* Header */}
            <Box sx={{ display: 'flex', bgcolor: 'action.hover', borderBottom: 1, borderColor: 'divider' }}>
                <Box sx={{ width: 40, borderRight: 1, borderColor: 'divider', textAlign: 'center' }}>
                    <Typography variant="caption">Byte</Typography>
                </Box>
                {[7, 6, 5, 4, 3, 2, 1, 0].map(bit => (
                    <Box key={bit} sx={{ width: 30, borderRight: bit === 0 ? 0 : 1, borderColor: 'divider', textAlign: 'center' }}>
                        <Typography variant="caption">{bit}</Typography>
                    </Box>
                ))}
            </Box>

            {/* Rows */}
            {Array.from({ length: bytes }).map((_, byteIdx) => (
                <Box key={byteIdx} sx={{ display: 'flex', borderBottom: byteIdx === bytes - 1 ? 0 : 1, borderColor: 'divider' }}>
                    <Box sx={{ width: 40, borderRight: 1, borderColor: 'divider', textAlign: 'center', bgcolor: 'action.hover', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Typography variant="caption">{byteIdx}</Typography>
                    </Box>
                    {[7, 6, 5, 4, 3, 2, 1, 0].map(bitIdxInByte => {
                        const bitIndex = byteIdx * 8 + bitIdxInByte;
                        const sig = getSignalAtBit(bitIndex);
                        const isSelected = sig && sig.name === selectedSignalName;
                        const isStart = sig && sig.start === bitIndex;
                        
                        return (
                            <Box 
                                key={bitIndex} 
                                onClick={() => onBitClick(bitIndex)}
                                sx={{ 
                                    width: 30, 
                                    height: 30,
                                    borderRight: bitIdxInByte === 0 ? 0 : 1, 
                                    borderColor: 'divider', 
                                    display: 'flex', 
                                    alignItems: 'center', 
                                    justifyContent: 'center',
                                    cursor: 'pointer',
                                    bgcolor: isSelected ? 'primary.light' : (sig ? 'action.selected' : 'background.paper'),
                                    color: isSelected ? 'primary.contrastText' : 'inherit',
                                    '&:hover': {
                                        bgcolor: isSelected ? 'primary.main' : 'action.hover'
                                    }
                                }}
                                title={sig ? `${sig.name} (Bit ${bitIndex})` : `Bit ${bitIndex}`}
                            >
                                <Typography variant="caption" sx={{ fontWeight: isStart ? 'bold' : 'normal', textDecoration: isStart ? 'underline' : 'none' }}>
                                    {bitIndex}
                                </Typography>
                            </Box>
                        );
                    })}
                </Box>
            ))}
        </Box>
    );
};
