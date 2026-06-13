# hairline

A [KOReader](https://github.com/koreader/koreader) plugin that reshapes the
reader's bottom progress bar into a minimal, full-width strip:

- **Stick the bar to the bottom screen edge** — eliminates the gap caused by
  the footer container's bottom padding *and* by the vertical centering inside
  the footer (the latter is what makes "Bottom margin: 0" alone insufficient
  when the bar is in *alongside* position).
- **Render the unread side fully transparent** — instead of painting a
  rectangle that competes with the page background (or shows as a visible
  outline in night/sepia mode), only the read portion, chapter tick marks,
  and the initial-position marker are drawn. The right side of the bar shows
  the page underneath it.
- **Adjustable bar height** — quick spinner for 1–30 px, separate from
  KOReader's deeper *Sizes and margins* submenu.

All three options live in *Status bar settings → Hairline*. Settings persist
in `settings/hairline.lua` next to your KOReader config.

## Origins

Inspired by the **Crosspoint** firmware mode for the **xteink 4** e-reader,
which renders its progress bar as a thin, flush-bottom strip — a clean look
this plugin tries to reproduce on stock KOReader.

This plugin was 100 % vibecoded: every line was drafted by an LLM
(Claude Opus) in conversation with the maintainer, then read, tested, and
shipped as-is. No manual translation or rewriting between drafts. It will
show.

## Install

Copy or symlink the `hairline.koplugin/` directory into your KOReader plugins
folder:

| Platform | Path |
|---|---|
| Linux (native) | `~/.config/koreader/plugins/` |
| Kobo / Kindle / PocketBook | `koreader/plugins/` on the device |
| Android | `koreader/plugins/` in KOReader's storage folder |

Then restart KOReader. The new entry appears under
*Tap centre top of screen → Settings → Status bar → Hairline*.

## How it works

The plugin monkey-patches three methods on
`apps/reader/modules/readerfooter.lua` at load time:

- **`updateFooterContainer`** — forces `self.bottom_padding = 0` before the
  container is rebuilt, then sets `horizontal_group.align = "bottom"` on the
  freshly created group so the progress bar drops to the bottom of its row
  instead of being vertically centred.
- **`init`** — re-applies the above plus the transparent `paintTo` on the
  progress bar instance for fresh book opens.
- **`addToMainMenu`** — injects our submenu into the existing
  `menu_items.status_bar.sub_item_table`, so the options appear inside the
  *Status bar* settings group rather than under *Tools → More tools*.

The transparent rendering is an instance-level override of
`ProgressWidget:paintTo` (only on the footer's `progress_bar`, not on every
progress widget in KOReader). It skips the background and border rectangles
entirely; only the filled fraction, chapter ticks, and initial-position
marker are painted. Chapter ticks remain drawn in the original
`bordercolor`, so they stay visible on top of the page underneath.

The plugin does *not* permanently mutate the user's
`progress_style_thin`/`progress_bar_position` settings. It only sets a few
fields on the existing footer instance per refresh; toggling either feature
off via the menu reverts the override on the next refresh.

## Compatibility

Tested on KOReader 2026.03 on Linux (Wayland / labwc, Raspberry Pi). The
plugin relies on `ReaderFooter`, `ProgressWidget`, and the `HorizontalGroup`
`align = "bottom"` mode — all stable KOReader APIs.

## Translations

User-facing strings use KOReader's central gettext domain (`koreader.mo`),
which means: if a translation for the exact English msgid happens to exist
upstream, you get it for free; otherwise the English source is shown. KOReader
does not provide per-plugin translation catalogues, so adding more languages
realistically means submitting the strings upstream once they stabilise. PRs
welcome either way.

## License

AGPL-3.0-or-later, same as KOReader. See `LICENSE`.

## Tags

`koreader` · `koreader-plugin` · `e-reader` · `e-ink` · `progress-bar`
· `footer` · `status-bar` · `minimal-ui` · `xteink` · `crosspoint`
· `lua` · `agpl-3.0`
