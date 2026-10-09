# Splina: instructions for contributors and agents

Splina is the vector geometry library of the AMAGE UI ecosystem, implemented in
**Bend 2**: paths, curves, transforms, and an explicit SVG subset, prepared for
rasterization by Dithra and composition by Chromi. Read the README for current
capabilities and limits; a roadmap item (arcs, strokes, clipping, general SVG)
is not implemented merely because it appears in the project scope.

## Implementation

- Implement library logic in Bend 2, rather than wrapping an equivalent SVG or
  vector engine written in another language.
- The official Bend compiler/runtime, OS APIs, and drivers remain external
  dependencies. Splina needs no native bridge.
- Before writing Bend, run `bend version` and read `bend guide` from the installed
  toolchain. Verify available syntax/effects instead of assuming old examples work.
- `path.bend` is shared with Runika and Dithra as `../Splina/path.bend`. Keep its
  path and types stable, or update the dependent libraries in the same change.
- Unsupported SVG features must be rejected with an error, never silently
  ignored. Do not pre-convert fixtures to hide a limit.
- Keep source, comments, documentation, and commit messages in English.

## Writing fast Bend

Correct Bend is not fast Bend by default. Measured rules (Bend 2.0.35):

- Indexed, large or hot data (bytes, pixels, coverage, quads) lives in an
  `Array<U32>` (native flat block, ~1 ns/read), not a `List`. Lists are fine
  when tiny, built once and consumed in order. Arrays are affine and cannot be
  fields of `Data` types: keep them local and convert once at the boundary.
- No `do Result`/`do Maybe` binds or callbacks per byte, pixel or glyph: each
  bind is a closure (45% of a measured profile). Thread state through one
  recursive def that matches on the result.
- `||`, `&&` and `Bool.pick` evaluate both sides; use `match` to stop early.
- Never `Array.clone` or append (`List.append`) in a loop; build with a
  reversed accumulator or a tail parameter.
- A parameter that a def only matches or passes to itself is borrowed (no
  refcount); descend trees with the selector as a parameter.
- Keep non-recursive records small (they are passed flattened; the widest one
  widens every call frame). Box big ones with an `Alias{x: T}` constructor.
- Split independent, balanced work of tens of µs or more with a parallel call
  (`a b = f(l) g(r)`); never parallelize tiny or IO-bound work.
- Measure before and after on the same input; print a result before the next
  `IO.now()`.

Here: real inputs are tiny (a few paths and segments), so lists consumed in
order are fine. Per-shape work could fork for icon sets with many paths of
similar size; measure first.

## Linux first

The initial goal is excellent behavior on Ian's actual Linux development machine:
correctness, stability, measured performance, and a finished user experience.
Inspect the effective environment before choosing integrations.

Build compatibility layers as the project progresses, after visible, well-made
Linux results. Do not let speculative Windows or macOS abstractions delay local
quality. Introduce abstractions from concrete needs.

## Working practice

- Preserve existing work and keep the library's boundary clear: flattening and
  rasterization belong to Dithra, composition to Chromi.
- Favor simple, maintainable code. Pursue fast, polished behavior with evidence.
- Run the native checks after changes. Validate affected rendering in a real
  window when visible output changes, compare with an independent reference
  where possible, then close the window.
- Compilation is not visual proof. Runtime checks are not proofs of the entire
  system. State partial support and unverified behavior explicitly.
- Build sequentially. Do not impose virtual-address limits on the Bend compiler
  or runtime, or suppress crash reporting. Large structural matches over
  strings have made compilation expensive here; see
  [docs/history.md](docs/history.md). Investigate failures before retrying.
- Keep generated binaries, logs, crash dumps, credentials, and machine-specific
  evidence out of Git. Stage explicit paths and preserve concurrent changes.

See [CONTRIBUTING.md](CONTRIBUTING.md) for validation commands.
