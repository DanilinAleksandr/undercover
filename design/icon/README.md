# Launcher icon

`undercover_icon.svg` is the only source of the icon. Nothing else in the
repository holds its geometry — edit the SVG, run the script, commit the PNGs.

```bash
powershell -ExecutionPolicy Bypass -File tool/generate_icon.ps1
```

The script finds Inkscape (installer does not put it on PATH), renders the
three artboards of the SVG by area and writes every asset Android needs. It
fails loudly if Inkscape is missing or an export produces nothing.

## The three artboards

| Area in the SVG      | Group                  | Produces                              |
|----------------------|------------------------|---------------------------------------|
| `0:0:1024:1024`      | `#artboard-icon`       | `mipmap-*/ic_launcher.png`, store 512 |
| `1216:0:2240:1024`   | `#artboard-foreground` | `mipmap-*/ic_launcher_foreground.png` |
| `2432:0:3456:1024`   | `#artboard-monochrome` | `mipmap-*/ic_launcher_monochrome.png` |

The symbol itself lives once, in `#mark` on the first artboard. The other two
artboards are `<use>` clones of it, so the geometry cannot drift apart. Each
artboard is clipped to its own square — the vignette and the atmosphere blur
far past 1024 px and would otherwise bleed into the next artboard's export.

The adaptive background is `@color/ic_launcher_background` (`#07080D`), not an
image, so nothing is rendered for it.

## Why the adaptive layers are PNG and not VectorDrawable

The foreground and monochrome layers carry a Gaussian-blurred gold glow, and
the monochrome layer is itself produced by an SVG filter. Android's
`VectorDrawable` has no filter primitives at all — no blur, no colour matrix —
so a vector version would have to drop the glow, which changes how the icon
looks. Visual identity wins over file size: both layers stay PNG, rendered
from the same SVG at every density.

Everything else in the mark (paths, clip paths, flat fills) would convert
cleanly; it is only the two filters that do not.

## Note on the blur falloff

The soft washes fade with the *square* of the blur (`feFuncA type="gamma"
exponent="2"`). That is not decoration: it reproduces the falloff the icon was
designed against, and it keeps the glow tight instead of blooming over the
silhouette.
