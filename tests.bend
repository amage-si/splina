import Base
import ./main.bend as S
import ./path.bend as P
import ./geometry.bend as G
import ./transform.bend as T

def check(name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def near(a: F32, b: F32) -> Bool:
  (F32.abs(F32.sub(a,b)) < 0.00001 : F32)

def point(p: P.Point, x: F32, y: F32) -> Bool:
  match p:
    case P.Point{px,py}:
      near(px,x) && near(py,y)

def valid_path(data: String) -> Bool:
  Result.is_done(&2,&1,String,P.Path,S.parse_path(data,P.NonZero{}))

def bad_path(data: String) -> Bool:
  Bool.not(valid_path(data))

def valid_svg(data: String) -> Bool:
  Result.is_done(&2,&1,String,S.Svg,S.parse_svg(data))

def bad_svg(data: String) -> Bool:
  Bool.not(valid_svg(data))

def relative_result(r: Result<&2,&1,String,P.Path>) -> Bool:
  match r:
    case Done{P.Path{P.MoveTo{a} <> P.Line{b} <> P.Line{c} <> P.Line{d} <> P.Line{e} <> P.ClosePath{} <> P.Line{f} <> Nil{},_}}:
      point(a,1.0,2.0) && point(b,3.0,4.0) && point(c,5.0,4.0) && point(d,5.0,7.0) && point(e,4.0,5.0) && point(f,2.0,2.0)
    case _:
      False{}

def quadratic_result(r: Result<&2,&1,String,P.Path>) -> Bool:
  match r:
    case Done{P.Path{P.MoveTo{_} <> P.Quad{_,_} <> P.Quad{c,p} <> Nil{},_}}:
      point(c,6.0,F32.neg(4.0)) && point(p,8.0,0.0)
    case _:
      False{}

def cubic_result(r: Result<&2,&1,String,P.Path>) -> Bool:
  match r:
    case Done{P.Path{P.MoveTo{_} <> P.Cubic{_,_,_} <> P.Cubic{c1,c2,p} <> Nil{},_}}:
      point(c1,4.0,4.0) && point(c2,5.0,5.0) && point(p,6.0,6.0)
    case _:
      False{}

def fill_result(r: Result<&2,&1,String,P.Path>) -> Bool:
  match r:
    case Done{P.Path{P.MoveTo{_} <> P.Line{_} <> P.ClosePath{} <> P.MoveTo{_} <> P.Line{_} <> P.ClosePath{} <> Nil{},P.EvenOdd{}}}:
      True{}
    case _:
      False{}

def svg_result(r: Result<&2,&1,String,S.Svg>) -> Bool:
  match r:
    case Done{S.Svg{_,_,_,S.Shape{P.Path{P.MoveTo{a} <> P.Line{b} <> P.Line{c} <> P.ClosePath{} <> Nil{},P.EvenOdd{}},color} <> Nil{}}}:
      point(a,2.0,3.0) && point(b,4.0,3.0) && point(c,4.0,5.0) && U32.is_eq(color,4287103104)
    case _:
      False{}

def inverse_result(r: Result<&2,&1,String,P.Transform>) -> Bool:
  match r:
    case Fail{_}:
      False{}
    case Done{t}:
      point(P.point(t,P.Point{12.0,23.0}),1.0,1.0)

def main() -> IO(Unit):
  do IO<Unit>:
    check("quadratic midpoint",point(P.quadratic(P.Point{0.0,0.0},P.Point{4.0,8.0},P.Point{8.0,0.0},0.5),4.0,4.0))
    check("cubic midpoint",point(P.cubic(P.Point{0.0,0.0},P.Point{0.0,8.0},P.Point{8.0,8.0},P.Point{8.0,0.0},0.5),4.0,6.0))
    check("transform order",point(P.point(P.compose(P.translate(10.0,20.0),P.scale(2.0,3.0)),P.Point{1.0,1.0}),12.0,23.0))
    check("inverse transform",inverse_result(G.inverse(P.compose(P.translate(10.0,20.0),P.scale(2.0,3.0)))))
    check("singular transform",Result.is_fail(&2,&1,String,P.Transform,G.inverse(P.scale(0.0,1.0))))
    check("relative/implicit/close",relative_result(S.parse_path("M1 2 3 4 h2 v3 l-1-2 z l1 0",P.NonZero{})))
    check("smooth quadratic",quadratic_result(S.parse_path("M0 0Q2 4 4 0T8 0",P.NonZero{})))
    check("smooth cubic",cubic_result(S.parse_path("M0 0C1 1 2 2 3 3S5 5 6 6",P.NonZero{})))
    check("fraction and exponent",valid_path("m.1.2L1e1-2.5E-1z"))
    check("empty path",valid_path(""))
    check("arc rejected",bad_path("M0 0A1 1 0 0 0 2 2"))
    check("missing coordinates",bad_path("M0 0 L1"))
    check("missing first moveto",bad_path("L1 2"))
    check("number after close",bad_path("M0 0Z1 2"))
    check("invalid exponent",bad_path("M1e 2"))
    check("nonfinite number",bad_path("M1e999 2"))
    check("number coordinate limit",bad_path("M1000001 0"))
    check("relative coordinate limit",bad_path("M1000000 0l1 0"))
    check("double comma",bad_path("M0,,0"))
    check("leading comma",bad_path(",M0 0"))
    check("trailing comma",bad_path("M0 0,"))
    check("fill closes subpaths",fill_result(G.for_fill(P.Path{[P.MoveTo{P.Point{0.0,0.0}},P.Line{P.Point{1.0,0.0}},P.MoveTo{P.Point{2.0,0.0}},P.Line{P.Point{3.0,0.0}}],P.EvenOdd{}})))
    check("fill rejects malformed path",Result.is_fail(&2,&1,String,P.Path,G.for_fill(P.Path{[P.Line{P.Point{1.0,1.0}}],P.NonZero{}})))
    check("SVG inheritance and transforms",svg_result(S.parse_svg("<svg viewBox='0 0 16 16' fill-opacity='.5'><g transform='translate(2 3) scale(2)' fill='#f80' fill-rule='evenodd'><path d='M0 0L1 0L1 1Z'/></g></svg>")))
    check("paired path tag",valid_svg("<svg viewBox='0 0 16 16'><path d='M0 0L1 1'></path></svg>"))
    check("empty document",valid_svg("<svg viewBox='0 0 1 1'/>"))
    check("root viewBox required",bad_svg("<svg/>"))
    check("zero viewBox",bad_svg("<svg viewBox='0 0 0 1'/>"))
    check("zero width",bad_svg("<svg viewBox='0 0 1 1' width='0'/>"))
    check("mismatched group",bad_svg("<svg viewBox='0 0 1 1'><g></svg>"))
    check("duplicate attribute",bad_svg("<svg viewBox='0 0 1 1' fill='red' fill='black'/>"))
    check("missing attr whitespace",bad_svg("<svg viewBox='0 0 1 1'fill='red'/>"))
    check("entity rejected",bad_svg("<svg viewBox='0 0 1 1' id='a&amp;b'/>"))
    check("stroke rejected",bad_svg("<svg viewBox='0 0 1 1' stroke='red'/>"))
    check("CSS rejected",bad_svg("<svg viewBox='0 0 1 1' style='fill:red'/>"))
    check("clip rejected",bad_svg("<svg viewBox='0 0 1 1'><clipPath/></svg>"))
    check("unknown element",bad_svg("<svg viewBox='0 0 1 1'><circle/></svg>"))
    check("trailing XML",bad_svg("<svg viewBox='0 0 1 1'/>x"))
    check("bad transform arity",Result.is_fail(&2,&1,String,P.Transform,T.parse("matrix(1 2)")))
    check("bad transform delimiter",Result.is_fail(&2,&1,String,P.Transform,T.parse("scale(2")))
    IO.print("Splina: all checks passed; no claim of complete SVG support")
