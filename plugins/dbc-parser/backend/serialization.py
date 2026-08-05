import cantools

def db_to_json(db):
    if not db:
        return None
    
    nodes = []
    for n in db.nodes:
        nodes.append({
            "name": n.name,
            "comment": n.comment
        })
        
    messages = []
    for m in db.messages:
        signals = []
        for s in m.signals:
            signals.append({
                "name": s.name,
                "start": s.start,
                "length": s.length,
                "byte_order": s.byte_order,
                "is_signed": s.is_signed,
                "is_float": s.is_float,
                "scale": s.scale,
                "offset": s.offset,
                "minimum": s.minimum,
                "maximum": s.maximum,
                "unit": s.unit,
                "choices": s.choices,
                "comment": s.comment,
                "is_multiplexer": s.is_multiplexer,
                "multiplexer_ids": s.multiplexer_ids,
                "multiplexer_signal": s.multiplexer_signal,
                "receivers": s.receivers
            })
            
        messages.append({
            "frame_id": m.frame_id,
            "is_extended_frame": m.is_extended_frame,
            "name": m.name,
            "length": m.length,
            "senders": m.senders,
            "send_type": m.send_type,
            "cycle_time": m.cycle_time,
            "signals": signals,
            "comment": m.comment
        })
        
    return {
        "nodes": nodes,
        "messages": messages,
        "version": db.version
    }

def json_to_db(json_data):
    db = cantools.database.Database(version=json_data.get("version"))
    
    for n in json_data.get("nodes", []):
        node = cantools.database.can.Node(
            name=n["name"],
            comment=n.get("comment")
        )
        db.nodes.append(node)
        
    for m in json_data.get("messages", []):
        signals = []
        for s in m.get("signals", []):
            signal = cantools.database.can.Signal(
                name=s["name"],
                start=s["start"],
                length=s["length"],
                byte_order=s.get("byte_order", "little_endian"),
                is_signed=s.get("is_signed", False),
                is_float=s.get("is_float", False),
                scale=s.get("scale", 1),
                offset=s.get("offset", 0),
                minimum=s.get("minimum"),
                maximum=s.get("maximum"),
                unit=s.get("unit"),
                choices=s.get("choices"),
                comment=s.get("comment"),
                is_multiplexer=s.get("is_multiplexer", False),
                multiplexer_ids=s.get("multiplexer_ids"),
                multiplexer_signal=s.get("multiplexer_signal"),
                receivers=s.get("receivers", [])
            )
            signals.append(signal)
            
        message = cantools.database.can.Message(
            frame_id=m["frame_id"],
            name=m["name"],
            length=m["length"],
            signals=signals,
            is_extended_frame=m.get("is_extended_frame", False),
            senders=m.get("senders", []),
            send_type=m.get("send_type"),
            cycle_time=m.get("cycle_time"),
            comment=m.get("comment")
        )
        db.messages.append(message)
        
    return db
