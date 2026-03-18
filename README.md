# cute-hud

Floating status HUD for macOS — JSON lines in, beautiful panel out.

Dark translucent panel that hovers above all windows on every display. Built for multi-agent automation pipelines where you need to show humans what the machine is doing (and when not to touch anything).

<!-- Screenshots: place PNGs in docs/screenshots/ showing each mode -->
> **Screenshots coming soon** — the HUD renders as a 700x168pt dark panel with colored status dot, badge pill, action text, countdown timer, and an embee-inspired lure fact card at the bottom.

## Quick start

```bash
make build        # swift build -c release
make install      # copies to /usr/local/bin

# Pipe JSON to stdin:
echo '{"mode":"warning","title":"SIMEMU","action":"Tapping login button","countdown":5}' | cute-hud
```

Requires **macOS 13+** and Swift 5.9+.

## Modes

| Mode | Dot color | Default title | Blocking | Use case |
|------|-----------|---------------|----------|----------|
| `info` | Green | ACTIVE | No | Normal automation in progress |
| `warning` | Orange | TAKING OVER | No | About to interact with the screen |
| `error` | Red | ERROR | No | Something failed |
| `critical` | Bright red | DO NOT TOUCH | Yes | Screen locked — full overlay blocks mouse input |
| `paused` | Yellow | PAUSED | No | Waiting / human intervention needed |
| `idle` | Gray | IDLE | No | Hides the panel |

Mode aliases: `active`/`running` map to `info`, `pending` maps to `warning`.

## JSON protocol

### Stdin (commands to HUD)

**State updates** — any object with `mode` (or `state`):

| Field | Type | Description |
|-------|------|-------------|
| `mode` | string | `info`, `warning`, `error`, `critical`, `paused`, `idle` |
| `title` | string | Override the default title (uppercased) |
| `badge` | string | Pill badge text, e.g. `"TAPPING"` |
| `action` | string | Main action line, e.g. `"tap — Tap 250,500"` |
| `detail` | string | Secondary detail line |
| `task` | string | Small task identifier at the bottom |
| `countdown` | int | Countdown timer in seconds |
| `blocking` | bool | Show full-screen click-blocking overlay |
| `fact` | string | Lure fact text |
| `fact_emoji` | string | Emoji for fact card |
| `fact_category` | string | Category label (`ANIMALS`, `SCIENCE`, `SPACE`, etc.) |

**Scouty compatibility fields**: `state`, `stage`, `screen`, `scenario`, `platform` are also accepted.

**Commands** — objects with `command`:

| Command | Extra fields | Effect |
|---------|-------------|--------|
| `{"command": "hide"}` | — | Hide the panel |
| `{"command": "show"}` | — | Show the panel |
| `{"command": "sound", "name": "start"}` | `name`: `start`, `complete`, `error` | Play a system sound |

### Stdout (events from HUD)

| Event | When |
|-------|------|
| `{"event": "ready"}` | Process launched and panel created |
| `{"event": "shown"}` | Panel became visible |
| `{"event": "hidden"}` | Panel was hidden |

## Python helper

```bash
pip install -e .   # or just copy python/cute_hud.py into your project
```

```python
from cute_hud import CuteHUD

# Basic usage — panel shows on enter, hides on exit
with CuteHUD(mode="warning", title="SIMEMU", countdown=5) as hud:
    hud.update(badge="TAPPING", action="tap — Tap login button")
    do_work()

# Blocking mode — covers screen, prevents accidental clicks
with CuteHUD(mode="critical", title="DO NOT TOUCH", blocking=True) as hud:
    run_maestro_flow()

# Sound effects
hud.sound("start")     # Tink
hud.sound("complete")  # Glass
hud.sound("error")     # Basso
```

The helper auto-discovers the binary from `PATH`, `.build/release/`, or `~/dev/cute-hud/.build/release/`.

## Integration

### simemu

```python
with CuteHUD(mode="warning", title="SIMEMU", countdown=3) as hud:
    hud.update(badge="TAPPING", action="tap — Tap 250,500", task="login-flow")
    sim.tap(250, 500)
    hud.update(badge="SWIPING", action="swipe — Swipe up to scroll")
    sim.swipe(200, 600, 200, 200)
```

### scouty

Scouty can send its native lease metadata directly — the HUD understands `state`, `stage`, `screen`, `scenario`, and `platform` fields:

```python
hud.send({
    "state": "active",
    "stage": "tapping",
    "screen": "LoginScreen",
    "scenario": "happy-path",
    "platform": "ios",
})
```

The `stage` field is auto-compacted into badge text (`tapping` becomes `TAPPING`, `long_press` becomes `HOLDING`, etc.).

## Design

- **700x168pt** dark translucent panel (`NSVisualEffectView`, `.hudWindow` material)
- Rounded corners (18pt), subtle top-edge sheen, 1px border
- Renders on **every connected display**, centered at the top
- No dock icon, no menu bar — runs as an accessory process
- Colored status dot + auto-sized badge pill per mode
- Monospaced-digit countdown timer (28pt bold)
- **Lure fact card**: colored accent bar + emoji + category label + fact text, with per-category colors (animals=green, science=blue, space=purple, food=orange, etc.)
- Critical mode: full-screen semi-transparent overlay blocks all mouse input

## Install

```bash
make build     # swift build -c release
make install   # cp .build/release/cute-hud /usr/local/bin/
make clean     # swift package clean
```

## License

MIT
