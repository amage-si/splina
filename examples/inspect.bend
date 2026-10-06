import Base
import ../main.bend as S
import ../path.bend as P
import ../file.bend as SF

# Parses two real Bootstrap icons: one inside the supported subset, and one
# that uses arcs, which Splina rejects explicitly. Run from the repository root.
def count(list: +List<P.Segment>) -> U32:
  match list:
    case Nil{}:
      0
    case Con{s, rest}:
      (1 + count(rest) : U32)

def segments(path: P.Path) -> U32:
  P.Path{list, rule} = path
  count(list)

def shapes(list: +List<S.Shape>, n: U32, total: U32) -> U32 & U32:
  match list:
    case Nil{}:
      (n, total)
    case Con{S.Shape{path, fill}, rest}:
      shapes(rest, (n + 1 : U32), (total + segments(path) : U32))

def summary(w: F32, h: F32, totals: U32 & U32) -> String:
  (n, total) = totals
  F32.show(w) ++ "x" ++ F32.show(h) ++ ", " ++ U32.show(n) ++ " shape(s), " ++ U32.show(total) ++ " segment(s)"

def describe(name: String, result: Result<&2, &1, String, S.Svg>) -> IO(Unit):
  match result:
    case Fail{e}:
      IO.print(name ++ ": rejected: " ++ e)
    case Done{S.Svg{w, h, box, list}}:
      IO.print(name ++ ": " ++ summary(w, h, shapes(list, 0, 0)))

def main() -> IO(Unit):
  do IO<Unit>:
    heart : String <- SF.read("fixtures/heart-fill.svg")
    describe("heart-fill.svg", S.parse_svg(heart))
    github : String <- SF.read("fixtures/github.svg")
    describe("github.svg", S.parse_svg(github))
