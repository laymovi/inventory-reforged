import os
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
TOOLS = Path(os.environ.get("IR_TOOLS", PROJECT / "tools"))
BUILT = PROJECT / "out"
OUT = BUILT
# pose.py reads the bone dumps of a game run from this folder's Documents
STAND_INSTANCE = Path(os.environ.get("IR_GAME_RUN", PROJECT / "game-run"))
