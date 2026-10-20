# Echo brand kit and design system

Named for the nymph who repeats every word. The app hears you and gives it back written down, on your device.

See it live at echo.jaybulb.com/brand.html.

## The mark
A voice wave rings out, fades like an echo, and settles into a written line, over a shorter line. One bold flat white glyph on a blue gradient tile. No text, no outline, no emblem.

- `../Echo.icon` is the source of truth (Icon Composer). Light and dark fills are set in it.
- `../icon.svg` is the flat copy for READMEs (shown at 80 px). `icon-1024.png` is the App Store icon, no alpha.
- `mark.svg` is the glyph alone in `currentColor` for your own background.
- Clear space equals the stroke width. Smallest size 16 px. Always blue, never red.
- Rebuild all of it with the brand generator: `make_brand.py <repo> Echo "#4da6ff" "#0074D9" <glyph.svg> "<idea>"`.

## 1-bit art
Public domain paintings of Echo, the Muses and memory, ordered-dithered to one bit (4x4 Bayer) and stored in the alpha channel of `../docs/art/*.png`. The site uses them as masks, tinted with the band's light blue over film grain. Each image is used once. Credits sit in a comment in `../docs/index.html`.

## Colour
| Role | Value |
|---|---|
| Accent, icon bottom | `#0074D9` |
| Icon top | `#4da6ff` |
| Band (white text on it) | `#0062bd` |
| Action on paper | `#0067c7` |
| Art dots | `#8fc3f7` |
| Paper | `#fdfdfd` light, `#07111d` dark |
| Ink | `#1a1a1a` light, `#f2f4f7` dark |

Never brown, beige, purple or teal.

## Type
The system font (SF Pro) everywhere. The apps call `Font.echo(size, weight)`, which is `.system`. Display is the thinnest weight in caps, tracked tight. Labels are 13 px caps at 600, tracked .12em. Scale 34/41, 22/28, 17/24, 15/20, 13/16.

## Space and shape
- 8 point grid: 4, 8, 12, 16, 24, 32, 48, 64, 96. Reading column 680.
- Radii: web buttons and panels 2, rows 8, lists 20, cards 28, icon 22.5 percent, app controls fully round.
- App controls are 48 point capsules; the record button is the one circle. Focus ring at 30 percent accent. Motion 0.2 s ease, honours reduced motion.

`../docs/tokens.css` holds every token; `tokens.css` here links to it.
