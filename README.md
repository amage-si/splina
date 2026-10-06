# Splina

**Paths, curves, transforms, and a strict SVG subset for the AMAGE UI ecosystem, in Bend 2.**

Splina is the vector geometry library of the AMAGE ecosystem. It represents
paths with subpaths, quadratic and cubic Bézier curves, closing, and fill
rules; applies affine transforms; and parses an explicit subset of SVG into
filled shapes. The parser is written in Bend: no browser, resvg/usvg, Skia,
or hand-written native code. The same path type is shared with Runika (font
outlines) and Dithra (rasterization).

**Status:** early implementation, tested with **Bend 2.0.35** on Linux
(Hyprland with XWayland). The first priority is a polished, reliable
experience on the development Linux machine. Compatibility layers will follow
proven progress.

![The Bootstrap heart icon parsed by Splina, rasterized by Dithra, and composed by Chromi, captured from the demo window.](docs/preview.png)

The capture above is the SVG half of the PNG + SVG demo window: the original
Bootstrap `heart-fill` icon at 224x224 pixels. Compared with librsvg on the
same icon, 828 of 50,176 pixels differ, all on antialiased edges; at the
half-coverage threshold the shapes overlap with 99.9167% intersection over
union. The two rasterizers are not pixel-identical.

## What works today

- A path model with `MoveTo`, `Line`, `Quad`, `Cubic`, `ClosePath`, and
  `NonZero`/`EvenOdd` fill rules. Subpaths and explicit closing are preserved.
- Affine transforms: identity, translate, scale, rotate, composition, inverse
  (singular matrices rejected), applied to points and paths.
- Curve evaluation by de Casteljau (`lerp`, `midpoint`, `quadratic`, `cubic`).
- `for_fill`, an explicit adapter that closes open subpaths for filling without
  changing the original path, and conservative control-hull bounds.
- SVG path data: `M L H V Q T C S Z` in absolute and relative forms, implicit
  repetition, moveto followed by lineto, smooth-control reflection, adjacent
  signs, decimals, and exponents, with arity and separator validation.
- An SVG document subset: one `<svg>` with a required `viewBox`, nested `<g>`,
  `<path>`, solid fills, inherited `fill`/`fill-opacity`/`fill-rule`, and
  `matrix`/`translate`/`scale`/`rotate`/`skewX`/`skewY` transforms.
- Explicit rejection of everything outside the subset (see
  [Current boundaries](#current-boundaries)), and bounded work on every input.
- `render.bend`, an adapter that maps a parsed SVG into a pixel square
  (`xMidYMid meet`) and draws it through Dithra and Chromi.

The native suite has **40 checks**: quadratic/cubic evaluation,
composition/inverse/singular transforms, relative and repeated commands, Q/T
and C/S control points, closing, number syntax, invalid separators, numeric
limits, inheritance and transforms, malformed XML, duplicate attributes,
entities, and unsupported features.

The PNG + SVG demo (`examples/png_svg.bend`) was compiled and opened on Linux:
it showed the kitty PNG decoded by Ocula and the heart SVG parsed by Splina,
then closed itself after 900 frames (about 15 s) with exit 0. The PNG region
matched an independent reference on all 65,536 pixels, including partial
alpha. See [docs/history.md](docs/history.md) for how that run and the
compiler-memory incident were measured.

## Quick start

Requirements: the [Bend 2 toolchain](https://bend-lang.com) and Clang 14 or
newer. The parser, geometry, and tests have no sibling dependencies and need no
display. Compiling the test suite peaked at about 1.6 GiB of resident memory.

```sh
git clone https://github.com/amage-si/splina.git Splina
cd Splina
export BEND_NO_TELEMETRY=1
bend version
mkdir -p build
bend tests.bend -o build/tests
./build/tests --threads 2 --gpu off
```

Parse two real icons, one inside the subset and one that uses arcs:

```sh
bend examples/inspect.bend -o build/inspect
./build/inspect --threads 2 --gpu off
```

```text
heart-fill.svg: 16x16, 1 shape(s), 3 segment(s)
github.svg: rejected: SVG elliptical arc A/a is unsupported
```

### The PNG + SVG window demo

The demo and `render.bend` need sibling repositories cloned beside Splina,
keeping their capitalized directory names, because Bend imports are
case-sensitive relative paths: [Dithra](https://github.com/amage-si/dithra)
(rasterizer), [Chromi](https://github.com/amage-si/chromi) (canvas),
[Ocula](https://github.com/amage-si/ocula) (PNG decoder), and
[Ankra](https://github.com/amage-si/ankra) (window). Dithra's rasterizer imports
`../Splina/path.bend` back. Running it needs an X11 display, directly or
through XWayland, and reads the PNG icon installed by the kitty terminal at
`/usr/share/pixmaps/kitty.png` (not part of this repository).

```sh
bend examples/png_svg.bend -o build/png_svg
./build/png_svg --threads 2 --gpu off
```

The window is 640x368 and closes itself after 900 frames. Compiling it peaked
at about 1.9 GiB of resident memory, including the C compiler.

## The contract

```bend
import Base
import ./Splina/main.bend as S
import ./Splina/path.bend as P
```

| Function | Contract |
| --- | --- |
| `S.parse_path(data, rule)` | `Result<&2, &1, String, P.Path>` with absolute coordinates; curves are not flattened. |
| `S.parse_svg(source)` | `Result<&2, &1, String, S.Svg>`; `currentColor` is opaque black. |
| `S.parse_svg_with_color(source, rgba)` | Same, with the `currentColor` paint given as RGBA8. |

`Svg{width, height, viewBox, shapes}` holds `Shape{path, fill}` in document
order. Paints are `0xRRGGBBAA`, sRGB, straight alpha. SVG coordinates grow
downward; Runika keeps font units with y up, and Dithra declares its
conversion to screen space. Read the [API reference](docs/api.md) for the
geometry functions, the full subset, and the limits.

## Current boundaries

- Rejected explicitly: elliptical arcs `A/a`, strokes (only `stroke="none"` is
  accepted), CSS and `style`, group opacity, clip/mask/filter, gradients,
  `use`/`href`, images, other elements, DTDs, comments, processing
  instructions, XML entities, and unknown attributes. There is no external
  resource loading. This is not general SVG or XML support.
- `width`/`height` must be positive unitless numbers; percentages and units
  such as `px` are not accepted. Commas between transform functions are not
  supported.
- Input limits: source and values up to 65,536 characters, numbers up to 64
  characters, coordinates within ±1,000,000, up to 8,192 segments per path,
  512 shapes, group depth 16, 4,096 element steps, and 64 transforms or
  attributes. Parser loops have explicit fuel and no `@unsafe`.
- Not streaming: tokens, attributes, and segments are Bend lists with linear
  copies. Duplicate-attribute detection is O(a²) with a ≤ 64. No constant-time,
  zero-copy, or compact-memory claim is made.
- Flattening and rasterization belong to Dithra. A shape the parser accepts can
  still be refused by the rasterizer's budget; that error is returned.
- `render.bend` requires a canvas at scale 1 and a viewport square in
  `(0, 512]` pixels. It resets the canvas clip when done; restore your own clip
  afterwards if you need it.
- The demo presents through the official runtime's CPU/X11 path. Splina makes no
  GPU, resize, or interaction claim.

The Bend checker and these tests are not a formal proof of the library,
runtime, or integration.

## Repository map

| Path | Purpose |
| --- | --- |
| [path.bend](path.bend) | `Point`, `Segment`, `FillRule`, `Path`, `Transform`, curve evaluation. |
| [geometry.bend](geometry.bend) | `for_fill`, `bounds`, `inverse`. |
| [main.bend](main.bend) | `parse_path`, `parse_svg`, `parse_svg_with_color`, `Svg`, `Shape`. |
| [parsepath.bend](parsepath.bend) | SVG path-data parser. |
| [xml.bend](xml.bend), [lex.bend](lex.bend) | Strict XML tags/attributes and number lexing. |
| [style.bend](style.bend), [transform.bend](transform.bend) | Paint, fill rules, viewBox, inheritance, transform lists. |
| [render.bend](render.bend) | Adapter to Dithra's rasterizer and Chromi's canvas. |
| [file.bend](file.bend) | Small file-reading helper for examples. |
| [tests.bend](tests.bend) | Native checks; no display needed. |
| [examples/](examples/) | `inspect.bend` (terminal) and `png_svg.bend` (window demo). |
| [fixtures/](fixtures/) | Original Bootstrap Icons SVGs and their MIT license. |
| [docs/](docs/) | API reference and validation history. |

## Fixtures

The SVGs in `fixtures/` are unmodified [Bootstrap Icons](https://github.com/twbs/icons)
(MIT, see `fixtures/BOOTSTRAP-LICENSE`): `heart-fill.svg` uses supported cubics
and has no `Z`, so filling goes through `for_fill`; `github.svg`,
`caret-up-fill.svg`, and `triangle-fill.svg` contain arcs and mark the boundary
of the subset. Only `heart-fill.svg` and `github.svg` are exercised by the
examples; the arc fixtures are not yet run as file tests.

## Dependencies

- Core (paths, geometry, parser, tests, `examples/inspect.bend`): the Bend 2
  toolchain and its `Base` library only.
- `render.bend`: Dithra and Chromi beside Splina.
- `examples/png_svg.bend`: Dithra, Chromi, Ocula, and Ankra beside Splina;
  X11/XWayland; the system kitty icon.

[Runika](https://github.com/amage-si/runika) and Dithra import
`../Splina/path.bend`; keep that path stable.

## Direction

Next: elliptical arcs and more metadata with tests, other contours and coverage
tolerances measured against independent references, strokes, and clipping,
without introducing external engines. These are goals, not supported features.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development rules. The API is
experimental and may change. Licensed under either of [Apache License 2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT), at your option.
Reference: [SVG 1.1 paths](https://www.w3.org/TR/SVG11/paths.html).

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE))
- MIT license ([LICENSE-MIT](LICENSE-MIT))

at your option. Unless you explicitly state otherwise, any contribution
intentionally submitted for inclusion in this work, as defined in the
Apache-2.0 license, shall be dual licensed as above, without any additional
terms or conditions.
