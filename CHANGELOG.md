# Changelog

All notable changes to Splina are recorded here. Splina follows
[semantic versioning](https://semver.org) in its 0.x form: while the API is
experimental, a minor version (0.2.0) may change it in breaking ways and a
patch version (0.1.1) only fixes. Splina is built from source together with its
sibling AMAGE libraries; the set of versions tested together is listed in
[eco-build's releases](https://github.com/amage-si/eco-build/tree/main/releases).

## [0.1.0] - 2026-10-09

First tagged release, tested with Bend 2.0.35 on Linux (X11/XWayland) as part
of AMAGE Eco 0.1.0.

### Included

- Path model with lines, quadratic and cubic curves, closing and fill rules.
- Affine transforms and curve evaluation.
- SVG path data and a strict SVG document subset, rejecting everything
  outside it explicitly.
- `render.bend` to draw a parsed SVG through Dithra and Chromi.
- 40 native checks.

[0.1.0]: https://github.com/amage-si/splina/releases/tag/v0.1.0
