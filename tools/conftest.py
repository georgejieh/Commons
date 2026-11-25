"""Puts the tools and the voice synthesis folder on the import path for every test."""

import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent

for folder in (TOOLS, TOOLS / "voice_proto"):
    if str(folder) not in sys.path:
        sys.path.insert(0, str(folder))
