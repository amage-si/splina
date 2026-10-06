import Base
import ./path.bend as P
import ./lex.bend as L

type FillState is Data:
  FillState{reversed: +List<P.Segment>, first: Maybe<&2,P.Point>, current: Maybe<&2,P.Point>, closed: Bool}

def close_previous(acc: +List<P.Segment>, first: Maybe<&2,P.Point>, closed: Bool) -> +List<P.Segment>:
  match first closed:
    case Some{_} False{}:
      P.ClosePath{} <> acc
    case _ _:
      acc

def reopen(acc: +List<P.Segment>, current: P.Point, closed: Bool) -> +List<P.Segment>:
  match closed:
    case False{}:
      acc
    case True{}:
      P.MoveTo{current} <> acc

def fill_step(segment: P.Segment, state: FillState) -> Result<&2,&1,String,FillState>:
  match segment state:
    case P.MoveTo{+to} FillState{acc,first,_,closed}:
      Done{FillState{P.MoveTo{to} <> close_previous(acc,first,closed),Some{to},Some{to},False{}}}
    case P.ClosePath{} FillState{acc,Some{+first},_,False{}}:
      Done{FillState{P.ClosePath{} <> acc,Some{first},Some{first},True{}}}
    case P.ClosePath{} FillState{acc,Some{first},current,True{}}:
      Done{FillState{acc,Some{first},current,True{}}}
    case P.Line{+to} FillState{acc,first,Some{current},closed}:
      Done{FillState{P.Line{to} <> reopen(acc,current,closed),first,Some{to},False{}}}
    case P.Quad{c,+to} FillState{acc,first,Some{current},closed}:
      Done{FillState{P.Quad{c,to} <> reopen(acc,current,closed),first,Some{to},False{}}}
    case P.Cubic{c1,c2,+to} FillState{acc,first,Some{current},closed}:
      Done{FillState{P.Cubic{c1,c2,to} <> reopen(acc,current,closed),first,Some{to},False{}}}
    case _ _:
      Fail{"path segment before MoveTo"}

def fill_loop(xs: +List<P.Segment>, state: Result<&2,&1,String,FillState>, rule: P.FillRule) -> Result<&2,&1,String,P.Path>:
  match xs state:
    case _ Fail{e}:
      Fail{e}
    case Nil{} Done{FillState{acc,first,_,closed}}:
      Done{P.Path{List.reverse(&2,P.Segment,close_previous(acc,first,closed)),rule}}
    case s <> rest Done{st}:
      fill_loop(rest,fill_step(s,st),rule)

# Explicit adapter: SVG fills open subpaths as closed. Original path is unchanged.
def for_fill(+path: P.Path) -> Result<&2,&1,String,P.Path>:
  match path:
    case P.Path{+ss,rule}:
      do Result<&2,&1,String,P.Path>:
        u : Unit <- L.require(P.valid(path),"non-finite or excessive path coordinates")
        u : Unit <- L.require((U32.from_nat(List.length(&2,P.Segment,ss)) <= 8192 : U32),"path segment limit (8192)")
        fill_loop(ss,Done{FillState{Nil{},None{},None{},True{}}},rule)

type Bounds is Data:
  Bounds{left: F32,top: F32,right: F32,bottom: F32}

def include(bounds: Maybe<&2,Bounds>, p: P.Point) -> Maybe<&2,Bounds>:
  match bounds p:
    case None{} P.Point{+x,+y}:
      Some{Bounds{x,y,x,y}}
    case Some{Bounds{l,t,r,b}} P.Point{+x,+y}:
      Some{Bounds{F32.min(l,x),F32.min(t,y),F32.max(r,x),F32.max(b,y)}}

def include_segment(s: P.Segment, bounds: Maybe<&2,Bounds>) -> Maybe<&2,Bounds>:
  match s:
    case P.MoveTo{p}:
      include(bounds,p)
    case P.Line{p}:
      include(bounds,p)
    case P.Quad{c,p}:
      include(include(bounds,c),p)
    case P.Cubic{c1,c2,p}:
      include(include(include(bounds,c1),c2),p)
    case P.ClosePath{}:
      bounds

def bounds_loop(ss: +List<P.Segment>, bounds: Maybe<&2,Bounds>) -> Maybe<&2,Bounds>:
  match ss:
    case Nil{}:
      bounds
    case s <> rest:
      bounds_loop(rest,include_segment(s,bounds))

# Conservative control-hull bounds, not exact Bézier extrema.
def bounds(path: P.Path) -> Maybe<&2,Bounds>:
  match path:
    case P.Path{ss,_}:
      bounds_loop(ss,None{})

def finite_transform(t: P.Transform) -> Bool:
  match t:
    case P.Transform{a,b,c,d,e,f}:
      P.finite(a) && P.finite(b) && P.finite(c) && P.finite(d) && P.finite(e) && P.finite(f)

def inverse(t: P.Transform) -> Result<&2,&1,String,P.Transform>:
  match t:
    case P.Transform{+a,+b,+c,+d,+e,+f}:
      +det = (a * d - b * c : F32)
      do Result<&2,&1,String,P.Transform>:
        u : Unit <- L.require((F32.abs(det) > 0.000000000001 : F32),"singular or ill-conditioned transform")
        +out : P.Transform = P.Transform{(d / det : F32),F32.neg((b / det : F32)),F32.neg((c / det : F32)),(a / det : F32),((c * f - d * e) / det : F32),((b * e - a * f) / det : F32)}
        u : Unit <- L.require(finite_transform(out),"inverse transform outside coefficient limit")
        return out
