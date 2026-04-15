# Add Your Music Here

Drop a music file into this folder and rename it to match what's in `scripts/Main.gd`.

## Default expected filename
```
song.ogg
```

## Supported formats
| Format | Notes |
|--------|-------|
| `.ogg` | Best — Godot handles it natively, no import issues |
| `.mp3` | Works but requires Godot's MP3 import plugin |

## How to get a .ogg file
- Export from Audacity: File → Export → OGG Vorbis
- Convert online: any "mp3 to ogg" converter works fine
- GarageBand, FL Studio, etc. can export OGG directly

## No music?
That's fine — the game runs without it. The beat clock uses your system
clock instead, and you'll still see the visual metronome and get scored.
