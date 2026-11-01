"""Where the Papyrus compiler is and what it imports, see the build steps in the readme"""

import os
from pathlib import Path

from common.paths import TOOLS

CAPRICA = TOOLS / "caprica" / "app" / "Caprica.exe"
IMPORTS = [Path(folder) for folder in os.environ.get("PAPYRUS_IMPORTS", "").split(";") if folder]
FLAGS = Path(os.environ.get("PAPYRUS_FLAGS", "TESV_Papyrus_Flags.flg"))
