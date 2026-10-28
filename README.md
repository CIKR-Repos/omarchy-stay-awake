# Stay Awake for Omarchy

Keep your Omarchy laptop awake from the bar: no screensaver, lock or suspend,
**even with the lid closed**, and the mouse moved now and then so apps like
Teams or Slack don't mark you as away.

## Install

```sh
omarchy plugin add https://github.com/CIKR-Repos/omarchy-stay-awake.git --enable
```

A coffee cup appears in the bar:

- **Click** opens the settings panel.
- **Right-click** turns Stay Awake on or off.

While the panel is open it has the keyboard, like every Omarchy panel. Press
**Esc** or click outside it to close it.

### Lid close without locking

Omarchy locks the screen when the lid closes. To skip that lock while Stay
Awake is on, add this to `~/.config/hypr/bindings.lua`:

```lua
hl.unbind("switch:on:Lid Switch")
o.bind("switch:on:Lid Switch", nil, os.getenv("HOME") .. "/.config/omarchy/plugins/cikr-repos.stay-awake/stay-awake lid-close", { locked = true })
```

When Stay Awake is off, or **Lock when lid closes** is on, the lid behaves
exactly as before.

## Settings

| Section | Setting | Default |
|---|---|---|
| Keep awake | Keep screen on (no screensaver, screen-off or idle lock) | on |
| | Block sleep | on |
| | Keep running with lid closed | on |
| | Lock when lid closes | off |
| Mouse movement | Move the mouse | on |
| | Every: 10s to 10 min | 60s |
| | Distance: 1 to 50 px | 1 px |
| | Speed: Instant, Smooth, Slow | Instant |
| | Pattern: Nudge, Random, Square | Nudge |
| Turn off | After: Never, 30m, 1h, 2h, 4h, 8h | Never |
| | On battery below: Never, 10%, 20%, 30% | Never |
| Other | Notifications | on |

Changes apply at once, even while Stay Awake is on. Settings are stored in
`~/.config/omarchy/stay-awake.json`.

## How it works

- Turns on Omarchy's own stay-awake (`omarchy toggle idle`), and gives it back
  as it was when you turn Stay Awake off.
- Holds a logind inhibitor for `idle`, `sleep` and `handle-lid-switch` in a
  user unit, `omarchy-stay-awake.service`. The lid-switch lock is honoured by
  logind even with `LidSwitchIgnoreInhibited=yes`, so a closed lid no longer
  suspends. No root access and no change to `logind.conf`.
- Moves the cursor through Hyprland (`hl.dsp.cursor.move`) and puts it back.

A closed laptop that stays awake keeps using battery and gets warm in a bag;
**Turn off on battery below** is there for that.

## Command line

```sh
stay-awake on|off|toggle|status
stay-awake get                  # settings and state as JSON
stay-awake set interval 120     # any setting from the table
stay-awake test                 # move the mouse once
```

The script lives at
`~/.config/omarchy/plugins/cikr-repos.stay-awake/stay-awake`; link it into
`~/.local/bin` to use it as `stay-awake`.

## License

MIT
