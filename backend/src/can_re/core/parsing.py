class ParsingService:
    def __init__(self):
        self._parser = None

    def set_parser(self, parser):
        """Register a parser plugin instance."""
        self._parser = parser

    def is_available(self):
        """Check if a parser is currently registered and active."""
        return self._parser is not None

    def decode_message(self, frame_id: int, data: list | bytes, is_extended_id: bool = False):
        """Decode a single CAN frame."""
        if self._parser and hasattr(self._parser, 'decode_message'):
            return self._parser.decode_message(frame_id, data, is_extended_id)
        return None

    def decode_chunk(self, frames: list):
        """
        Decode a chunk of frames.
        Expected frame format: {"id": int, "data": list, "is_extended_id": bool, "decoded": None}
        Returns the list of frames with "decoded" populated.
        """
        if self._parser and hasattr(self._parser, 'decode_chunk'):
            # Allow the parser to optimize bulk decoding if it wants
            return self._parser.decode_chunk(frames)
        
        # Default fallback: loop over messages
        if self._parser:
            for frame in frames:
                frame["decoded"] = self.decode_message(frame["id"], frame["data"], frame.get("is_extended_id", False))
        
        return frames

    def get_database(self):
        """Get the parsed database metadata (for UI tools)."""
        if self._parser and hasattr(self._parser, 'get_database'):
            return self._parser.get_database()
        return None
