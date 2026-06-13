local _ = require("gettext")
return {
    name        = "hairline",
    fullname    = _("Hairline"),
    description = _([[Reshapes the reader's bottom progress bar into a minimal, full-width strip: sticks it to the bottom screen edge, renders the unread side fully transparent (only the read portion and chapter ticks are painted), and adds a quick height spinner. Options live under Status bar settings → Hairline.]]),
    version     = "0.1.0",
}
