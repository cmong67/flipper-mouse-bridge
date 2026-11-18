from pathlib import Path
root=Path(__file__).resolve().parent.parent
source=(root/'shared/spectrum_feedback.h').read_bytes()
for dest in ['cardputer/Firmware/src/spectrum_feedback.h','unified/Flipper/spectrum_feedback.h']:
    (root/dest).write_bytes(source)
