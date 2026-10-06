# Contributing to Splina

Use Bend 2.0.35 for the current baseline. Read `bend guide` before editing Bend
and keep project text in English. Library implementation belongs in Bend; the
official runtime and operating system remain external dependencies.

## Validation

From the repository root:

```sh
export BEND_NO_TELEMETRY=1
mkdir -p build
bend tests.bend --check-only
bend tests.bend -o build/tests
./build/tests --threads 2 --gpu off
bend examples/inspect.bend -o build/inspect
./build/inspect --threads 2 --gpu off
```

These need no display and no sibling repositories. Compiling the test suite
peaks at about 1.6 GiB of resident memory.

When a change affects rendering, clone Dithra, Chromi, Ocula, and Ankra beside
this directory (capitalized names) and run the window demo from the Splina root
in an X11/XWayland session:

```sh
bend examples/png_svg.bend -o build/png_svg
./build/png_svg --threads 2 --gpu off
```

Check the rendered icon in the window itself. A successful build alone does not
validate the output. When `path.bend` changes, also build Runika and Dithra.

Build one target at a time. The native Bend runtime reserves substantial virtual
address space; a virtual-memory limit is not a resident-memory limit. Preserve
crash evidence and investigate before repeating a failed compiler invocation.

## Changes

Keep the accepted subset explicit. Add a focused regression check for each
accepted or rejected feature, update [docs/api.md](docs/api.md) and the
README boundaries, and report what was actually validated. New fixtures need a
clear license; add it next to the files.

Use English commit messages that explain the result. Do not commit `build/`,
generated C, logs, crash dumps, credentials, or machine-specific paths. Do not
publish BendHub packages or create releases as a side effect of validation.

Compatibility work follows concrete Linux progress. New SVG features need
explicit implementations and their own checks before being advertised as
supported.
