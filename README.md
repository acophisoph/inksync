# InkSync

> Draw in sync. Level up both skills.

InkSync is a rhythm-drawing hybrid game that simultaneously trains your drawing technique and your sense of rhythm. Think of the spell-casting mechanics from *Epic Mickey* or *Arx Fatalis* — but fused with the precision timing of *osu!* or *Beat Saber*, and built around a structured drawing curriculum with AI feedback.

---

## Core Concept

Most drawing practice apps are passive. Most rhythm games are pure reflex. InkSync makes both active at the same time:

- The **beat drives your strokes** — you draw to the music, not around it
- The **drawing tests your control** — rhythm isn't just tapping, it's guiding a line with intention
- **AI analyzes both** — were your strokes on time? Were they smooth? Did the shape match?

The result is "double training": your muscle memory for drawing improves because the rhythm forces consistent timing and pressure, and your rhythm improves because your hand has to stay deliberate.

---

## Gameplay Modes

### Shape Tracing Mode (Calligraphy / Fundamentals)
A ghost stroke or shape appears on screen. Hit the beat and trace it — the game scores you on:
- **Timing** — did your stroke start and end on beat?
- **Smoothness** — wavering lines lose points
- **Accuracy** — how closely did you follow the path?

Great for learning fundamental strokes: lines, curves, circles, ellipses, and calligraphy letterforms.

### Free-Draw Mode (Prompt-Based)
A prompt appears (word, image reference, or category). You have a set number of measures to draw it from scratch. The AI grades you on:
- **Shape similarity** — computer vision comparison against a reference
- **Stroke quality** — per-stroke smoothness, direction, and confidence analysis
- **Completion** — did you finish within the time signature?

Great for building observational drawing skills and creative speed.

---

## AI Feedback System

InkSync uses two layers of analysis after each drawing:

1. **Shape Similarity Score** — Computer vision compares your output to the target. Highlights regions that diverged (too small, wrong angle, missing features).
2. **Stroke-Level Analysis** — Each individual stroke is evaluated for:
   - Smoothness (jitter / wobble detection)
   - Directional accuracy (did it go where intended?)
   - Timing alignment (on beat, rushed, or dragging?)

Feedback is shown immediately after each round and logged to your progress history.

---

## Music System

- **Curated soundtrack** — built-in tracks across tempos and genres (lo-fi, EDM, classical, jazz) with hand-crafted beat maps and prompt sets
- **Custom song import** — import any audio file; the game auto-detects BPM and generates a beat map. Players can also manually author prompt sequences for their tracks.

Song tempo determines challenge: slower BPM = more time per stroke = easier. Higher BPM = precision under pressure.

---

## Curriculum Structure

### Structured Lessons
A built-in drawing course that mirrors real art education:
1. **Fundamentals** — straight lines, curves, basic pressure control
2. **Shapes** — circles, ellipses, boxes in perspective
3. **Objects** — still life, everyday items
4. **Characters** — stylized figures, faces, expressions
5. **Advanced** — dynamic poses, composition, style

Each lesson has a target BPM range. As you pass lessons, harder tempos unlock.

### Song-Driven Prompt Packs
Each curated song comes with a themed prompt pack that fits its mood. A slow lo-fi track might prompt: *coffee cup, open book, rainy window*. A fast drum-and-bass track might prompt: *lightning bolt, running figure, explosion*.

---

## Progression

- Completing lessons unlocks new difficulty tiers and new songs
- Your drawings are saved to an in-game **portfolio** — a visual record of your improvement over time
- Per-skill stats track: stroke smoothness trend, shape accuracy trend, timing consistency
- Achievements for streaks, high accuracy, BPM milestones

---

## Platforms

Cross-platform target. Input methods in priority order:
1. Drawing tablet (Wacom, XP-Pen, etc.) — highest fidelity, closest to real drawing
2. Touchscreen (iOS / Android)
3. Mouse — fully playable, lower precision ceiling

---

## Tech Stack

> To be decided. Candidates:

| Engine | Pros | Cons |
|--------|------|------|
| **Unity (C#)** | Large rhythm/drawing game ecosystem, ML.NET integration, cross-platform builds | License costs at scale, heavier runtime |
| **Godot (GDScript/C#)** | Open source, excellent 2D input, fast iteration, no royalties | Smaller ecosystem, fewer ML plugins |
| **Web (TypeScript + Canvas/WebGL)** | Zero install, instant sharing, great for early prototyping | Audio latency risk for rhythm precision, harder to package |

Initial recommendation: **Godot** for prototyping (fast 2D iteration, free, great tablet input API), migrate to Unity if ML integration or platform store distribution becomes a bottleneck.

---

## Inspiration

| Game | What we borrow |
|------|----------------|
| *osu!* | Hit windows, accuracy scoring, custom song import |
| *Beat Saber* | Beat-reactive feedback, flow state through music |
| *Epic Mickey / Arx Fatalis* | Drawing as a primary game mechanic |
| *Scribblenauts* | Freeform drawing recognized and interpreted |
| *Duolingo* | Structured progressive curriculum with streaks |
| *Procreate* | Stroke smoothing, pressure sensitivity, portfolio |

---

## Project Status

Early concept / pre-production.

- [ ] Engine decision
- [ ] Prototype: shape tracing mode (single song, 4 beat windows)
- [ ] Stroke analysis pipeline
- [ ] Shape similarity scoring
- [ ] Custom song BPM detection
- [ ] Free-draw mode
- [ ] Curriculum lesson 1: lines & curves
- [ ] Portfolio / progress tracking
- [ ] Platform builds (PC first)

---

## Contributing

This is a solo/early-stage project. Design doc and architecture notes coming soon. Feel free to open issues with ideas or feedback.

---

*InkSync — where the beat teaches your hand.*
