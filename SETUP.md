# Running InkSync

## Step 1 — Install Godot 4

Download **Godot Engine 4.x** (use the **Standard** version, not Mono/C#):

> https://godotengine.org/download

It's a single executable — no installer, no PATH setup needed.

---

## Step 2 — Open the Project

1. Launch Godot
2. On the Project Manager screen, click **Import**
3. Navigate to this repo folder and select `game/project.godot`
4. Click **Open** → then **Import & Edit**

The editor opens. You'll see the `Main` scene in the scene tree on the left.

---

## Step 3 — Add Music (Optional)

Drop a `.ogg` or `.mp3` file into `game/assets/music/` and name it:

```
song.ogg
```

See `game/assets/music/PUT_SONG_HERE.md` for format tips and how to
convert files to .ogg.

> **No music?** No problem. Skip this step entirely. The beat clock runs
> off your system clock and the visual metronome still works. You'll still
> get scored on smoothness and shape accuracy.

---

## Step 4 — Run It

Press **F5** (or click the **▶ Play** button in the top-right of the editor).

A 1280×720 window opens. You'll see:

| Element | What it is |
|---------|-----------|
| Off-white background | Your drawing canvas |
| Faint blue circle outline | The ghost stroke — trace this |
| Blue dot, orange dot | Start and end markers on the ghost |
| Pulsing yellow ring (top-left) | Beat visualizer — the ring fills per beat, flashes on the beat |

**Draw the circle** with your mouse (hold left-click and drag).
After you lift the mouse button, your score appears for 3 seconds.

---

## Customizing

### Change BPM
Open [game/scripts/Main.gd](game/scripts/Main.gd) — line 12:
```gdscript
const BPM := 120.0   # ← change this number
```

### Change which beats to draw on
Lines 17–18 in `game/scripts/Main.gd`:
```gdscript
const START_BEAT := 1   # pen-down should land on this beat
const END_BEAT   := 3   # pen-up should land on this beat
```
At 120 BPM, 2 beats = 1 second. At 80 BPM, 2 beats = 1.5 seconds.

### Add a new reference stroke
1. Create a new `.json` file in `game/assets/strokes/`
2. Format — an array of `[x, y]` pairs tracing the shape:
   ```json
   [[440,260],[840,260],[840,460],[440,460],[440,260]]
   ```
   Coordinates are screen pixels. Origin (0,0) is top-left. Canvas is 1280×720.
3. Update line 10 in `Main.gd`:
   ```gdscript
   const STROKE_PATH := "res://assets/strokes/your_shape.json"
   ```

### Drawing tablet
Godot reads tablets automatically on Windows (WinTab / Pointer API) and macOS.
Pressure is available — the canvas records it per-point, ready for future
use in line width variation.

---

## Project Structure

```
game/
├── project.godot              ← Godot project config — import this to open
├── scenes/
│   └── Main.tscn              ← Root scene (just loads Main.gd)
├── scripts/
│   ├── Main.gd                ← Orchestrator — start here when reading code
│   ├── BeatClock.gd           ← BPM timing, beat phase, timestamps
│   ├── DrawingCanvas.gd       ← Mouse/tablet input + stroke rendering
│   ├── GhostStroke.gd         ← Reference path loader and renderer
│   ├── BeatVisualizer.gd      ← Pulsing metronome dot (top-left corner)
│   ├── StrokeAnalyzer.gd      ← Shape accuracy + smoothness + timing scorer
│   └── ScoreOverlay.gd        ← Post-stroke result panel (3-second display)
└── assets/
    ├── music/                 ← Drop song.ogg here
    └── strokes/               ← JSON reference paths
        └── circle.json        ← Built-in circle tracing challenge
```

---

## Troubleshooting

**Black screen on launch**
Check the Godot **Output** panel at the bottom of the editor. Usually a
script error with a file path or typo. The most common cause: a `class_name`
referenced before its file was loaded. Hit F5 again — Godot sometimes needs
one reload after importing a fresh project.

**"No song found" warning in Output**
Expected if you skipped Step 3. The game still runs.

**Ghost circle not visible**
Check that `game/assets/strokes/circle.json` exists. If you moved files,
update `STROKE_PATH` in `Main.gd`.

**Score always shows 0% accuracy**
Make sure you're dragging (not just clicking). A stroke needs at least
2 recorded points. Hold the mouse button and drag across the canvas before releasing.

**Tablet pressure not working**
On Windows, Godot 4 uses the Pointer API by default. If pressure reads as
0 on your tablet, try enabling "WinTab" in Project Settings →
Input Devices → Pointing.
