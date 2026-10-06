# Validation history

A short record of how Splina was validated during its first development
round (October 2026, Bend 2.0.35, Linux with Hyprland/XWayland), and of a
compiler-memory incident that shaped the current build guidance.

## Compiler abort under a virtual-memory limit

The first native build of the test suite ran under `ulimit -v` of 6 GiB
(virtual address space, not resident memory). The Bend compiler, which runs on
Bun, aborted with `ASSERTION FAILED: MemoryExhaustion` after about 21.5 s, at
roughly 4.1 GB RSS and 4.6 GB committed, before producing a binary. No OOM kill
was recorded and the machine had RAM available, so the virtual-memory limit is
the strong suspect, though not proven to be the only cause. It was a compiler
abort, not a crash of the library or of the native runtime.

Before the next attempt, large structural `match`es over SVG name strings
combined with records were replaced by classification through `String.eq` and
dispatch on small `U32` codes. Public APIs and types did not change. The
native build then succeeded without any virtual-memory limit: 18.1 s, about
1.6 GiB sampled peak RSS for the whole process tree, and all 40 checks passed.
That result does not separate how much of the original abort came from the
structural matches and how much from the limit.

Guidance that follows from it: build one target at a time, do not set
`RLIMIT_AS`/`ulimit -v` on the compiler or the native runtime (the runtime
alone reserves about 8 GiB of virtual space even when its resident use is
small), keep crash reports, and investigate before retrying.

## PNG + SVG demo

`examples/png_svg.bend` combines Ocula (PNG decoding), Splina (SVG parsing),
Dithra (rasterization), Chromi (composition), and Ankra (window). A first
build was stopped by the round's own 1,920 MiB RSS guard (SIGTERM, not a
compiler abort). A single rebuild with a 3 GiB guard succeeded in 25.4 s, with
a sampled aggregate peak of about 1.9 GiB, of which roughly 1.6 GiB was the
Bend compiler and the rest Clang compiling the generated C.

The demo was opened once and captured from its own window. It showed the
kitty PNG and the Bootstrap heart, closed itself after 900 frames (15.15 s)
with exit 0, and left no window behind. An external request to close it early
failed (the window-manager dispatch returned exit 7); the program's own frame
budget ended it normally.

An independent reference built with librsvg (for the SVG) and ImageMagick (for
the scene) was compared with the capture:

- PNG region: all 65,536 pixels identical, including 1,445 with partial alpha.
- SVG region: 828 of 50,176 pixels differ, all touching partial coverage in at
  least one rasterizer; maximum channel difference 46/255, mean 0.077/255. At a
  fixed half-coverage threshold the shapes agree at 99.9167% intersection over
  union (28 pixels of symmetric difference).

This is agreement on one icon, not a claim of geometric equivalence between
rasterizers. librsvg and ImageMagick were used only as external references and
are not part of the Bend execution path. The supervision and comparison
scripts used in that round were tied to its one-off evidence directories and
are not included in this repository.
