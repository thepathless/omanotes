<<<<<<< HEAD
# OmaNotes

A quick-note scratchpad for [Omarchy](https://omarchy.org/) that docks to a
corner of your screen. Toggle it with a keybind or the bar icon, type,
close — your text is still there next time.

## Features

- Notes autosave to disk as you type (debounced, no save button).
- Rich text: bold, italic, underline, and font size via the in-panel toolbar.
- Docks to any of the four screen corners; automatically clears whichever
  edge the Omarchy bar is docked to (top/bottom/left/right).
- Adjustable note size by dragging the corner grip, plus steppers in settings.
- Configurable note background color.
- The toggle keybind is rebindable from inside the panel itself.
- Optional status-bar icon (📝) that toggles the same panel.
- **Pin button**: keeps the panel open while using other windows.

## Install

```
omarchy plugin add https://github.com/thepathless/omanotes.git --enable
```

Add the bar icon (optional):

```
omarchy bar put omanotes --section right
```

Add a keybind, e.g. in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + R", "Toggle OmaNotes", "omarchy-shell shell toggle omanotes")
```

## State files

- `~/.local/state/omarchy/omanotes/notes.txt` — your notes (rich text).
- `~/.local/state/omarchy/omanotes/settings.json` — font size, position, keybind, size, background color.

## License

MIT — see [LICENSE](LICENSE).
=======
# omanotes
OmaNotes — Omarchy scratchpad notes plugin
>>>>>>> ebf369c (Initial commit)
