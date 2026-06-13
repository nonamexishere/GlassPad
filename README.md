# GlassPad

A translucent scratchpad that's always one keystroke away. Press **⌥Space** anywhere on macOS and a frosted-glass note panel floats up — jot something down, press **Esc**, keep working.

- **Global toggle** — ⌥Space shows/hides the panel from any app, without stealing focus from what you're doing.
- **See-through** — frosted-glass background (HUD material); a mini slider adjusts the panel's opacity from solid to barely-there, so you can read what's underneath while you type.
- **Always on top, everywhere** — floats above all windows, follows you across Spaces, stays put when you switch apps. Drag anywhere on its background to move it, or drag an edge to resize it.
- **One persistent note** — a single scratchpad that autosaves on every keystroke and survives restarts. No files, no documents, no save button. An empty note shows a hint, and a live word/character count sits in the bottom-right corner.

## Build & run

Requires macOS 13+ and Xcode (or the Swift toolchain).

```sh
swift build -c release
.build/release/GlassPad
```

Or during development: `swift run GlassPad`.

No special permissions needed — unlike clipboard tools, GlassPad only listens for its own hotkey.

## Usage

| Action | How |
|---|---|
| Show / hide the note | **⌥Space** (or the 📝 menu bar icon) |
| Hide | **Esc** |
| Move the panel | drag its background |
| Resize the panel | drag any edge or corner |
| Bigger / smaller text | **⌘+** / **⌘−** (reset with **⌘0**) |
| Adjust transparency | slider in the bottom-left corner |
| Quit | menu bar icon → Quit GlassPad |

## Roadmap

- [ ] Proper `.app` bundle + signed releases (Homebrew cask)
- [ ] Configurable hotkey
- [ ] Markdown rendering

## License

[MIT](LICENSE)
