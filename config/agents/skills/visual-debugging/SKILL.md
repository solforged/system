---
name: visual-debugging
description: Capture what a terminal UI or desktop app actually shows over time, to debug flicker, jitter, reflow, wrong sizes, layout or rendering glitches. Covers screenshots, short screen videos split into frames, pane text snapshots, and tracing a program's terminal writes; includes Rex pane caveats.
---

# Visual debugging

Look before you fix. Pick the cheapest capture that can show the bug, record a
repro, read it back, and state what the evidence shows before changing code.

| Bug | Capture |
|---|---|
| Wrong static layout, colours, clipping | Screenshot |
| Flicker, jitter, animation, anything sub-second | Write trace (exact) or video frames |
| Wrong text in a terminal pane | Pane text snapshot |
| Redraw storms, reflow, resize handling | Write trace |

## Screenshot

`screencapture -x /tmp/shot.png`, then read the image. `-R x,y,w,h` crops to
a rectangle in screen points. The host process needs macOS Screen Recording
permission; a black or missing image means it lacks it.

## Video, split into frames

You cannot watch video, so record briefly and look at frames:

```sh
screencapture -x -v -V 3 /tmp/rec.mov           # 3 s of the whole screen
# Only frames that differ from the one before; jitter shows up as a burst.
ffmpeg -loglevel error -i /tmp/rec.mov -vf "select='gt(scene,0.003)',scale=1280:-1" -fps_mode vfr /tmp/f%03d.png
# Or a contact sheet: 12 frames at 10 fps in one image.
ffmpeg -loglevel error -i /tmp/rec.mov -vf "fps=10,scale=640:-1,tile=4x3" -frames:v 1 /tmp/sheet.png
```

Start the recording, then trigger the bug (or ask the user to, and say when).
Crop with `crop=w:h:x:y` in the filter to see small regions at full size.

## Pane text (Rex)

`rex capture -s SESSION -b BLOCK` prints a pane's screen; poll it in a loop for
a crude timeline. `rex block call -s S -b B size` gives its size and owner.

## Write trace

[scripts/trace-writes.mjs](scripts/trace-writes.mjs) logs every stdout write
of a Node program with timing, terminal size and rows repainted, plus resizes:

```sh
TRACE_FILE=/tmp/trace.log node --import ~/.agents/skills/visual-debugging/scripts/trace-writes.mjs app.js
```

When something else launches the program, add a temporary first import to it
(see the script header). For any other program, `script -q -r /tmp/rec.raw CMD`
records raw output; replay with `script -p`.

## Rex caveats

- A new pane is 80x24 with no owner until the Rex app shows it. Panes in a
  window the user isn't looking at are never sized, so reproduce in the
  user's visible window, usually by asking them to trigger it.
- `rex api call -s S session.view` shows split ratios; `rex events -s S --json`
  streams changes (`--all` cannot be combined with `-s`).

## Clean up

Remove temporary imports and debug logging, close test panes and windows, and
delete captures under `/tmp` before reporting.
