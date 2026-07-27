from dataclasses import dataclass

@dataclass(slots=True)
class CanFrame:
    timestamp: float
    arbitration_id: int
    data: bytes
    is_extended_id: bool = False
    is_rx: bool = True
    dlc: int = 0
    channel: str = ""
