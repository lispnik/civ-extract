# civ-extract

![Sid Meier's Civilization logo](docs/logo.png)

Extract all graphics assets from the DOS game **Sid Meier's Civilization (1991)**,
with a full sprite index. Written in Common Lisp as an ASDF system; dependencies
are managed with [ocicl](https://github.com/ocicl/ocicl).

![Master atlas of every 16×16 game sprite](docs/atlas.png)

*The master `atlas.png`: all 729 terrain, unit and city sprites from `SP257`,
`SP299`, `SPRITES` and `TER257`.*

## What it does

* Decodes every `*.PIC` file (107 of them) to a PNG.
* Slices the known sprite sheets into individual 16×16 tiles.
* Renders **one master `atlas.png`** containing every sprite.
* Extracts the 9 bitmap fonts from `FONTS.CV` into specimen sheets under `fonts/`.
* Writes **`sprite-index.json`** describing every asset, sprite and font.

## The file format

Civilization's `.PIC`/`.PAL` files use MicroProse's IFF-like chunked container.
Each chunk is `[u16 magic][u16 length][length bytes]`:

| magic | id | meaning |
|-------|----|---------|
| `0x304D` | `M0` | 256-entry VGA palette (6-bit RGB, ×4 to 8-bit) |
| `0x3045` | `E0` | 8bpp→4bpp colour-conversion table (not needed for output) |
| `0x3058` | `X0` | 8bpp image — `LZW` then `RLE` compressed |
| `0x3158` | `X1` | 4bpp image — `LZW` then `RLE` compressed |

The image chunk body is `width(u16) height(u16) bits(u8)` followed by the
compressed stream. **LZW**: codes packed LSB-first, min 8 / max 11 bits, no
clear code, code `256` ends the stream, dictionary resets when the code width
would exceed 11 bits. **RLE**: `0x90 N` repeats the previous byte to N copies
total; `0x90 0x00` is a literal `0x90`. Colour index 0 is transparent.

(Algorithm matches the CC0-licensed [CivOne](https://github.com/SWY1985/CivOne)
reference decoder.)

## The fonts

`FONTS.CV` holds 9 bitmap fonts: a `u16` count, then one `u16` offset per font
pointing at its glyph data. Each font's metadata (`first`/`last` char, bytes per
row, top/bottom row, x/y spacing) sits in the 7 bytes just before that pointer,
preceded by a per-char pixel-width table; glyph rows are 1bpp (MSB-first) and
stored row-interleaved across all chars. `civ-extract` renders each font to a
specimen sheet under `fonts/`.

![Civilization bitmap font specimen](docs/fonts.png)

*One of the nine fonts (`fonts/font2.png`), shown over a dark background — the
extracted PNGs are white glyphs on transparency.*

## Running it

ocicl has already fetched `zpng` and `com.inuoe.jzon` into `ocicl/`
(see `ocicl.csv`). To re-fetch on a fresh checkout:

```sh
ocicl install zpng com.inuoe.jzon
```

Then run the batch extractor from this directory (edit the `:source-dir` in
`run.lisp` to point at the game's `.PIC` files — default `~/Projects/CIVILIZATION/`):

```sh
sbcl --non-interactive --load run.lisp
```

Output lands in `extracted/`:

```
extracted/
  images/<NAME>.png        # every PIC as a full RGBA image
  sprites/<SHEET>/tile_RRR_CCC.png   # individual sprite tiles
  atlas.png                # all sprites rendered onto one sheet
  sprite-index.json        # index of every asset + sprite
```

## Usage

From a REPL (or `sbcl --load`), point `:source-dir` at the directory holding the
game's `.PIC` files:

```lisp
(asdf:load-system :civ-extract)

;; 1. Extract everything: full images, sliced tiles, atlas and JSON index.
(civ-extract:extract-all :source-dir #p"~/Projects/CIVILIZATION/"
                         :out-dir    #p"extracted/")
;; => writes extracted/images/*.png, extracted/sprites/<SHEET>/*.png,
;;    extracted/atlas.png and extracted/sprite-index.json

;; 2. Decode a single file into a PIC struct and inspect it.
(let ((pic (civ-extract:parse-pic #p"~/Projects/CIVILIZATION/SP257.PIC")))
  (format t "~A: ~Dx~D, ~D bpp~%"
          (civ-extract:pic-source pic)
          (civ-extract:pic-width pic)
          (civ-extract:pic-height pic)
          (civ-extract:pic-depth pic)))
;; => SP257: 320x200, 8 bpp

;; 3. Skip the per-tile PNGs and just build the images + atlas + index faster.
(civ-extract:extract-all :source-dir #p"~/Projects/CIVILIZATION/"
                         :write-tiles nil)
```

`extract-all` keywords:

| keyword | default | meaning |
|---------|---------|---------|
| `:source-dir` | `#p"../"` | directory containing the `.PIC` files |
| `:out-dir` | `#p"extracted/"` | where output is written |
| `:write-tiles` | `t` | also write one PNG per sliced sprite |
| `:skip-blank` | `t` | drop fully-transparent tiles |
| `:atlas-columns` | `32` | columns in the master `atlas.png` |

Or just run the bundled script, which calls `extract-all` for you:

```sh
sbcl --non-interactive --load run.lisp
```

## Sprite sheets that get sliced

A single sliced tile (`sprites/ICONPGA/tile_000_000.png`, cut from the `ICONPGA`
page):

![Sample sliced sprite — musketeers](docs/sample-sprite.png)

Tile geometry lives in `*sprite-sheets*` (`src/sprites.lisp`):

* **16×16 game sheets** — `SP257`, `SP299`, `SPRITES`, `TER257` (terrain, units,
  city graphics). These feed the master `atlas.png`.
* **ICONPG civilopedia pages** — `ICONPG1`–`ICONPG8` (3×3 improvement/category
  icons), `ICONPGA`–`ICONPGE` (2-column unit illustrations), `ICONPGT1`/`T2`
  (3×2 map previews). These are large tiles, so they're sliced and indexed but
  kept out of the 16×16 atlas (`:in-atlas nil`).

Add a `make-sheet-spec` entry to slice another file, e.g.:

```lisp
(make-sheet-spec "CITYPIX1" :tile-w 32 :tile-h 24 :cols 8 :rows 6
                 :in-atlas nil :label "city graphics")
```

`make-sheet-spec` keys: `:tile-w` `:tile-h` `:origin-x` `:origin-y` `:gap-x`
`:gap-y` `:cols` `:rows` `:label` `:in-atlas`. When `:cols`/`:rows` are omitted
they're computed from the image size and tile pitch.
