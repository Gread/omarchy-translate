# Translate — Omarchy plugin

Quick translations between **Swedish, Portuguese and English** from the
[Omarchy](https://omarchy.org) bar.

- Press **Super + Alt + T** (or click 󰗊 in the bar). If you have text selected
  anywhere, the panel opens with it already translated.
- Type or paste: the translation updates as you type. The source language is
  detected, and you see the other two languages at once (Swedish → Portuguese
  and English, and so on; any other language → all three).
- **From / To** chips pick the languages; **⇄** swaps them and turns the
  translation into the text, like Google Translate.
- Click a translation to copy it.

| Keys | |
|---|---|
| Alt + S / P / E | translate to Swedish / Portuguese / English |
| Alt + A | both other languages |
| Alt + X | swap |
| Ctrl + Enter | copy the first translation |
| Esc | close |

## Install

```bash
omarchy plugin add https://github.com/Gread/omarchy-translate.git --enable
```

Then bind the key in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + T", "Translate", "omarchy-shell gread.translate open")
```

Needs `curl`, `jq` and `wl-clipboard` (all present on Omarchy).

## Privacy

The text you translate is sent to Google Translate (the same service as the
website), with no account or API key. Up to 1500 characters per translation.

## License

MIT
