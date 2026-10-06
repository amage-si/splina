import Base
import ./lex.bend as L
import ./xml.bend as X
import ./path.bend as P
import ./parsepath.bend as D
import ./style.bend as S

type Shape is Data:
  Shape{path: P.Path, fill: U32}

type Svg is Data:
  Svg{width: F32, height: F32, viewBox: S.Box, shapes: +List<Shape>}

type Document is Data:
  Document{rest: String, stack: +List<S.Style>, shapes: +List<Shape>, width: F32, height: F32, box: S.Box, status: U32, count: U32}

# Internal dispatch only; public XML and SVG types remain unchanged.
type Mark is Data:
  Mark{code: U32,attrs: +List<X.Attr>,closing: Bool,empty: Bool,rest: String,name: String}

def mark(parsed: X.TagRead) -> Mark:
  match parsed:
    case X.TagRead{X.Tag{+name,attrs,closing,empty},rest}:
      Mark{L.name_id(["svg","g","path"],name,1),attrs,closing,empty,rest,name}

def root_config(cfg: S.Config, rest: String, empty: Bool) -> Result<&2,&1,String,Document>:
  match cfg:
    case S.Config{style,_,w,h,Some{S.Box{x,y,+bw,+bh}}}:
      width = Maybe.default(&2,F32,w,bw)
      height = Maybe.default(&2,F32,h,bh)
      Done{Document{rest,[style],Nil{},width,height,S.Box{x,y,bw,bh},Bool.pick(U32,empty,2,0),0}}
    case _:
      Fail{"SVG root requires a positive viewBox"}

def root(parsed: Mark, current: U32) -> Result<&2,&1,String,Document>:
  match parsed:
    case Mark{1,attrs,False{},empty,rest,_}:
      do Result<&2,&1,String,Document>:
        cfg : S.Config <- S.attributes(attrs,Done{S.config(S.base())},0,current)
        root_config(cfg,rest,empty)
    case _:
      Fail{"expected one root <svg> element"}

def shape(cfg: S.Config) -> Result<&2,&1,String,Shape>:
  match cfg:
    case S.Config{S.Style{fill,opacity,+rule,t},Some{d},_,_,_}:
      do Result<&2,&1,String,Shape>:
        path : P.Path <- D.parse(d,rule)
        +path : P.Path = P.transform(path,t)
        u : Unit <- L.require(P.valid(path),"SVG transformed coordinates exceed finite +/-1000000 limit")
        return Shape{path,S.paint(S.Style{fill,opacity,rule,P.identity()})}
    case _:
      Fail{"SVG path requires a d attribute"}

def push_shape(sh: Shape, rest: String, stack: +List<S.Style>, shapes: +List<Shape>, w: F32, h: F32, box: S.Box, empty: Bool, count: U32) -> Document:
  Document{rest,stack,sh <> shapes,w,h,box,Bool.pick(U32,empty,0,1),U32.inc(count)}

def group(cfg: S.Config, rest: String, +stack: +List<S.Style>, shapes: +List<Shape>, w: F32, h: F32, box: S.Box, empty: Bool, count: U32) -> Result<&2,&1,String,Document>:
  match cfg:
    case S.Config{style,_,_,_,_}:
      do Result<&2,&1,String,Document>:
        u : Unit <- L.require((U32.from_nat(List.length(&2,S.Style,stack)) < 17 : U32),"SVG group nesting limit (16)")
        return Document{rest,Bool.pick(+List<S.Style>,empty,stack,style <> stack),shapes,w,h,box,0,count}

def apply_tag(parsed: Mark, doc: Document, current: U32) -> Result<&2,&1,String,Document>:
  match parsed doc:
    case Mark{3,_,True{},False{},rest,_} Document{_,stack,shapes,w,h,box,1,count}:
      Done{Document{rest,stack,shapes,w,h,box,0,count}}
    case _ Document{_,_,_,_,_,_,1,_}:
      Fail{"path elements cannot contain children or text"}
    case Mark{1,_,True{},False{},rest,_} Document{_,s <> Nil{},shapes,w,h,box,0,count}:
      Done{Document{rest,Nil{},shapes,w,h,box,2,count}}
    case Mark{2,_,True{},False{},rest,_} Document{_,_ <> parent <> more,shapes,w,h,box,0,count}:
      Done{Document{rest,parent <> more,shapes,w,h,box,0,count}}
    case Mark{2,attrs,False{},empty,rest,_} Document{_,+style <> +more,shapes,w,h,box,0,count}:
      do Result<&2,&1,String,Document>:
        cfg : S.Config <- S.attributes(attrs,Done{S.config(style)},1,current)
        group(cfg,rest,style <> more,shapes,w,h,box,empty,count)
    case Mark{3,attrs,False{},empty,rest,_} Document{_,+style <> more,shapes,w,h,box,0,+count}:
      do Result<&2,&1,String,Document>:
        u : Unit <- L.require((count < 512 : U32),"SVG shape count limit (512)")
        cfg : S.Config <- S.attributes(attrs,Done{S.config(style)},2,current)
        sh : Shape <- shape(cfg)
        return push_shape(sh,rest,style <> more,shapes,w,h,box,empty,count)
    case Mark{_,_,_,_,_,name} _:
      Fail{"unsupported SVG element or mismatched closing tag: " ++ name}

def step(doc: Document, current: U32) -> Result<&2,&1,String,Document>:
  match doc:
    case Document{+rest,stack,shapes,w,h,box,status,count}:
      do Result<&2,&1,String,Document>:
        tag : X.TagRead <- X.read(rest)
        apply_tag(mark(tag),Document{rest,stack,shapes,w,h,box,status,count},current)

def loop(fuel: Nat, +current: U32, result: Result<&2,&1,String,Document>) -> Result<&2,&1,String,Svg>:
  match fuel result:
    case _ Fail{e}:
      Fail{e}
    case _ Done{Document{rest,_,shapes,w,h,box,2,_}}:
      do Result<&2,&1,String,Svg>:
        u : Unit <- L.require(String.is_empty(L.trim(rest)),"trailing content after root SVG")
        return Svg{w,h,box,List.reverse(&2,Shape,shapes)}
    case 0n Done{_}:
      Fail{"SVG element work limit (4096)"}
    case 1n+p Done{doc}:
      loop(p,current,step(doc,current))

def parse_svg_with_color(+source: String, +current: U32) -> Result<&2,&1,String,Svg>:
  do Result<&2,&1,String,Svg>:
    u : Unit <- L.require(L.within(65536n,source),"SVG source exceeds 65536 characters or contains invalid XML characters")
    first : X.TagRead <- X.read(source)
    loop(4096n,current,root(mark(first),current))

def parse_svg(source: String) -> Result<&2,&1,String,Svg>:
  parse_svg_with_color(source,255)

def parse_path(source: String, rule: P.FillRule) -> Result<&2,&1,String,P.Path>:
  do Result<&2,&1,String,P.Path>:
    +p : P.Path <- D.parse(source,rule)
    u : Unit <- L.require(P.valid(p),"SVG path coordinates exceed finite +/-1000000 limit")
    return p
