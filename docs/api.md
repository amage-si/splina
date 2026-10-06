# Splina API

The parser and geometry depend only on `Base` from the official Bend
toolchain. Import paths are relative to the calling file. An application next
to the `Splina` directory uses:

```bend
import Base
import ./Splina/main.bend as S
import ./Splina/path.bend as P
import ./Splina/geometry.bend as G
```

## Paths (`path.bend`)

```bend
Point{x: F32, y: F32}

Segment:
  MoveTo{to: Point}
  Line{to: Point}
  Quad{control: Point, to: Point}
  Cubic{control1: Point, control2: Point, to: Point}
  ClosePath{}

FillRule: NonZero{} | EvenOdd{}
Path{segments: +List<Segment>, rule: FillRule}
Transform{a, b, c, d, e, f: F32}     # x' = a*x + c*y + e;  y' = b*x + d*y + f
```

`MoveTo` starts a subpath; `ClosePath` records an explicit close and is not a
`Line`. The names `MoveTo` and `ClosePath` avoid `Base`'s `Move` and `Close`
window events. Splina, Runika, and Dithra share this module.

| Function | Contract |
| --- | --- |
| `identity()`, `translate(x, y)`, `scale(x, y)`, `rotate(radians)` | Transform constructors. |
| `compose(outer, inner)` | Applies `inner` first. |
| `point(t, p)`, `transform(path, t)` | Applies a transform to a point or every segment. |
| `lerp(a, b, t)`, `midpoint(a, b)` | Linear interpolation. |
| `quadratic(p0, p1, p2, t)`, `cubic(p0, p1, p2, p3, t)` | De Casteljau evaluation. `t` is not restricted to `[0, 1]`. |
| `valid(path)` | Every coordinate finite and within ±1,000,000. Not a structural check. |

## Geometry (`geometry.bend`)

| Function | Contract |
| --- | --- |
| `for_fill(path)` | `Result<&2, &1, String, P.Path>`. Validates structure, closes open subpaths, and reopens with a `MoveTo` when a segment follows `ClosePath`. An explicit fill adapter; the original path is unchanged. |
| `bounds(path)` | `Maybe<&2, Bounds{left, top, right, bottom}>`: the conservative control-point hull, not exact Bézier extrema. `None` for an empty path. |
| `inverse(t)` | `Result<&2, &1, String, P.Transform>`. Rejects a determinant with magnitude ≤ 1e-12 and non-finite or out-of-range coefficients. |

## SVG (`main.bend`)

```bend
Svg{width: F32, height: F32, viewBox: Style.Box, shapes: +List<Shape>}
Shape{path: P.Path, fill: U32}
Style.Box{x: F32, y: F32, width: F32, height: F32}   # from style.bend
```

| Function | Contract |
| --- | --- |
| `parse_path(data, rule)` | Path data to absolute coordinates. Curves are kept, not flattened. |
| `parse_svg(source)` | `currentColor` is opaque black. |
| `parse_svg_with_color(source, rgba)` | `currentColor` is the given RGBA8 paint. |

All three return `Result<&2, &1, String, _>`; the `String` explains the
rejection. Paints are `0xRRGGBBAA`, sRGB, straight alpha. SVG y grows downward.
Shapes follow document order, with group transforms already applied.

### Accepted subset

- One `<svg>` root with a **required** `viewBox`, nested `<g>`, and `<path>`,
  either self-closing or with `</path>`. Nothing may appear inside a path.
- Path data: `M/m L/l H/h V/v Q/q T/t C/c S/s Z/z`, implicit repetition, a
  moveto followed by implicit linetos, smooth-control reflection, adjacent
  signs, decimals, and exponents. Arity, the first moveto, and separators are
  validated.
- `fill`: `none`, `currentColor`, `black`, `white`, `red`, `#RGB`, `#RRGGBB`.
- `fill`, `fill-opacity` in `[0, 1]`, and `fill-rule` (`nonzero`/`evenodd`) are
  inherited. `fill-opacity` scales the paint alpha; it is not group opacity.
- `transform`: `matrix(a,b,c,d,e,f)`, `translate`, `scale`, `rotate` (degrees,
  optional center), `skewX`, `skewY`. Functions are separated by whitespace or
  are adjacent; arguments accept comma-wsp. Commas *between* functions are not
  supported. Groups accumulate transforms; attribute order does not matter.
- Root `width`/`height`: positive unitless numbers; when absent, the viewBox
  size is used.
- `xmlns` with the standard SVG namespace; `id` and `class` are inert metadata;
  `stroke="none"`.
- XML: quoted attribute values, no duplicate attributes, validated characters.

Everything else is rejected with an error, including arcs `A/a`, strokes, CSS
and `style`, group opacity, clip/mask/filter, gradients, `use`/`href`, images,
other elements, DTDs, comments, processing instructions, entities, and unknown
attributes. There is no external resource loading.

### Limits

| Item | Limit |
| --- | --- |
| Source and attribute values | 65,536 characters |
| A number | 64 characters, finite, within ±1,000,000 |
| Segments per path | 8,192 |
| Shapes | 512 |
| Group depth | 16 |
| Element steps | 4,096 |
| Transforms or attributes per element | 64 |

Parser loops run on explicit fuel; there is no `@unsafe`. Exceeding a limit is
an error, not a truncation.

## Rendering adapter (`render.bend`)

`draw(svg, canvas, x, y, size)` returns
`Result<&2, &1, String, Chromi.Canvas>`. It maps the viewBox into the pixel
square at `(x, y)` with side `size` using `xMidYMid meet`, closes subpaths with
`for_fill`, rasterizes each shape with Dithra's `rasterize_screen`, and blends
the coverage with Chromi's `blit_mask`. It requires a canvas at scale 1 and
`size` in `(0, 512]`, clips to the square, and resets the canvas clip at the
end. It needs [Dithra](https://github.com/amage-si/dithra) and
[Chromi](https://github.com/amage-si/chromi) beside Splina.

The API is not stable yet.
