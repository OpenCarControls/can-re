class StateManager:
    def __init__(self, events):
        self.events = events
        # Use a standard list for O(1) appending, which easily scales to millions of frames.
        self.frames = []
        
    def add_frame(self, frame):
        self.frames.append(frame)
        self.events.emit('frame_added', frame)

    def add_frames(self, frames: list):
        self.frames.extend(frames)
        self.events.emit('frames_loaded', len(self.frames))

    def clear(self):
        self.frames.clear()
        self.events.emit('frames_cleared', None)
