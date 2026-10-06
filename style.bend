import Base
import ./lex.bend as L
import ./path.bend as P
import ./xml.bend as X
import ./transform.bend as T

type Box is Data:
  Box{x: F32,y: F32,width: F32,height: F32}

type Style is Data:
  Style{fill: U32,opacity: F32,rule: P.FillRule,transform: P.Transform}

type Config is Data:
  Config{style: Style,data: Maybe<&2,String>,width: Maybe<&2,F32>,height: Maybe<&2,F32>,box: Maybe<&2,Box>}

def base() -> Style:
  Style{255,1.0,P.NonZero{},P.identity()}

def config(s: Style) -> Config:
  Config{s,None{},None{},None{},None{}}

def number_list(ns: +List<F32>) -> Result<&2,&1,String,F32>:
  match ns:
    case v <> Nil{}:
      Done{v}
    case _:
      Fail{"expected exactly one number"}

def number(s: String) -> Result<&2,&1,String,F32>:
  do Result<&2,&1,String,F32>:
    ns : +List<F32> <- L.numbers(s)
    number_list(ns)

def viewbox(ns: +List<F32>) -> Result<&2,&1,String,Box>:
  match ns:
    case x <> y <> +w <> +h <> Nil{}:
      do Result<&2,&1,String,Box>:
        u : Unit <- L.require((w > 0.0 : F32) && (h > 0.0 : F32),"SVG viewBox dimensions must be positive")
        return Box{x,y,w,h}
    case _:
      Fail{"SVG viewBox needs four numbers"}

def hex_digit(+c: U32) -> Result<&2,&1,String,U32>:
  +lower = U32.or(c,32)
  do Result<&2,&1,String,U32>:
    u : Unit <- L.require(L.digit(c) || ((lower >= 97 : U32) && (lower <= 102 : U32)),"invalid hexadecimal SVG color")
    return Bool.pick(U32,L.digit(c),U32.sub(c,48),U32.sub(lower,87))

def hex(s: String, acc: U32) -> Result<&2,&1,String,U32>:
  match s:
    case SNil{}:
      Done{acc}
    case SCon{Chr{c},t}:
      do Result<&2,&1,String,U32>:
        v : U32 <- hex_digit(c)
        hex(t,(acc * 16 + v : U32))

def color_hex(+s: String, n: U32) -> Result<&2,&1,String,U32>:
  match n:
    case 3:
      do Result<&2,&1,String,U32>:
        +v : U32 <- hex(s,0)
        return ((v / 256) * 17 * 16777216 + ((v / 16) % 16) * 17 * 65536 + (v % 16) * 17 * 256 + 255 : U32)
    case 6:
      do Result<&2,&1,String,U32>:
        v : U32 <- hex(s,0)
        return (v * 256 + 255 : U32)
    case _:
      Fail{"SVG colors support #RGB and #RRGGBB"}

def color(value: String, current: U32) -> Result<&2,&1,String,U32>:
  match value:
    case "none":
      Done{0}
    case "currentColor":
      Done{current}
    case "black":
      Done{255}
    case "white":
      Done{4294967295}
    case "red":
      Done{4278190335}
    case SCon{Chr{35},+s}:
      color_hex(s,U32.from_nat(String.length(s)))
    case _:
      Fail{"unsupported SVG paint (solid colors only)"}

def rule(value: String) -> Result<&2,&1,String,P.FillRule>:
  match value:
    case "nonzero":
      Done{P.NonZero{}}
    case "evenodd":
      Done{P.EvenOdd{}}
    case _:
      Fail{"unsupported SVG fill-rule"}

def attribute_id(name: String) -> U32:
  L.name_id(["fill","fill-rule","fill-opacity","transform","d","viewBox",
    "width","height","xmlns","stroke","id","class"],name,1)


def attribute_case(code: U32, name: String, v: String, cfg: Config, +kind: U32, current: U32) -> Result<&2,&1,String,Config>:
  match code cfg:
    case 1 Config{Style{_,o,r,t},d,w,h,b}:
      do Result<&2,&1,String,Config>:
        c : U32 <- color(v,current)
        return Config{Style{c,o,r,t},d,w,h,b}
    case 2 Config{Style{c,o,_,t},d,w,h,b}:
      do Result<&2,&1,String,Config>:
        r : P.FillRule <- rule(v)
        return Config{Style{c,o,r,t},d,w,h,b}
    case 3 Config{Style{c,_,r,t},d,w,h,b}:
      do Result<&2,&1,String,Config>:
        +o : F32 <- number(v)
        u : Unit <- L.require((o >= 0.0 : F32) && (o <= 1.0 : F32),"fill-opacity outside 0..1")
        return Config{Style{c,o,r,t},d,w,h,b}
    case 4 Config{Style{c,o,r,t},d,w,h,b}:
      do Result<&2,&1,String,Config>:
        local : P.Transform <- T.parse(v)
        +all : P.Transform = P.compose(t,local)
        u : Unit <- L.require(T.valid(all),"SVG transform accumulation exceeds limit")
        return Config{Style{c,o,r,all},d,w,h,b}
    case 5 Config{s,_,w,h,b}:
      do Result<&2,&1,String,Config>:
        u : Unit <- L.require(U32.is_eq(kind,2),"d attribute belongs to path")
        return Config{s,Some{v},w,h,b}
    case 6 Config{s,d,w,h,_}:
      do Result<&2,&1,String,Config>:
        u : Unit <- L.require(U32.is_eq(kind,0),"viewBox belongs to root svg")
        ns : +List<F32> <- L.numbers(v)
        b : Box <- viewbox(ns)
        return Config{s,d,w,h,Some{b}}
    case 7 Config{s,d,_,h,b}:
      do Result<&2,&1,String,Config>:
        u : Unit <- L.require(U32.is_eq(kind,0),"width belongs to root svg")
        +w : F32 <- number(v)
        u : Unit <- L.require((w > 0.0 : F32),"SVG width must be positive and unitless")
        return Config{s,d,Some{w},h,b}
    case 8 Config{s,d,w,_,b}:
      do Result<&2,&1,String,Config>:
        u : Unit <- L.require(U32.is_eq(kind,0),"height belongs to root svg")
        +h : F32 <- number(v)
        u : Unit <- L.require((h > 0.0 : F32),"SVG height must be positive and unitless")
        return Config{s,d,w,Some{h},b}
    case 9 c:
      do Result<&2,&1,String,Config>:
        u : Unit <- L.require(U32.is_eq(kind,0) && String.eq(v,"http://www.w3.org/2000/svg"),"unsupported SVG namespace")
        return c
    case 10 c:
      do Result<&2,&1,String,Config>:
        u : Unit <- L.require(String.eq(v,"none"),"SVG stroke is unsupported")
        return c
    case 11 c:
      Done{c}
    case 12 c:
      Done{c}
    case _ _:
      Fail{"unsupported SVG attribute " ++ name}

def attribute(attr: X.Attr, cfg: Config, kind: U32, current: U32) -> Result<&2,&1,String,Config>:
  match attr:
    case X.Attr{+name,value}:
      attribute_case(attribute_id(name),name,value,cfg,kind,current)

def attributes(attrs: +List<X.Attr>, cfg: Result<&2,&1,String,Config>, +kind: U32, +current: U32) -> Result<&2,&1,String,Config>:
  match attrs cfg:
    case _ Fail{e}:
      Fail{e}
    case Nil{} Done{c}:
      Done{c}
    case a <> rest Done{c}:
      attributes(rest,attribute(a,c,kind,current),kind,current)

def paint(style: Style) -> U32:
  match style:
    case Style{+color,opacity,_,_}:
      alpha = F32.to_u32(F32.round(F32.mul(U32.to_f32(U32.and(color,255)),opacity)))
      U32.or(U32.and(color,4294967040),alpha)
