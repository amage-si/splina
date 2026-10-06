import Base
import ./lex.bend as L
import ./xml.bend as X
import ./path.bend as P

def degrees(value: F32) -> F32:
  (value * 0.017453292519943295 : F32)

def operation_case(code: U32, values: +List<F32>) -> Result<&2,&1,String,P.Transform>:
  match code values:
    case 1 a <> b <> c <> d <> e <> f <> Nil{}:
      Done{P.Transform{a,b,c,d,e,f}}
    case 2 x <> Nil{}:
      Done{P.translate(x,0.0)}
    case 2 x <> y <> Nil{}:
      Done{P.translate(x,y)}
    case 3 +x <> Nil{}:
      Done{P.scale(x,x)}
    case 3 x <> y <> Nil{}:
      Done{P.scale(x,y)}
    case 4 angle <> Nil{}:
      Done{P.rotate(degrees(angle))}
    case 4 angle <> +cx <> +cy <> Nil{}:
      Done{P.compose(P.translate(cx,cy),P.compose(P.rotate(degrees(angle)),P.translate(F32.neg(cx),F32.neg(cy))))}
    case 5 angle <> Nil{}:
      Done{P.Transform{1.0,0.0,F32.tan(degrees(angle)),1.0,0.0,0.0}}
    case 6 angle <> Nil{}:
      Done{P.Transform{1.0,F32.tan(degrees(angle)),0.0,1.0,0.0,0.0}}
    case _ _:
      Fail{"unsupported transform or invalid argument count"}

def operation(name: String, values: +List<F32>) -> Result<&2,&1,String,P.Transform>:
  operation_case(L.name_id(["matrix","translate","scale","rotate","skewX","skewY"],name,1),values)

def valid(t: P.Transform) -> Bool:
  match t:
    case P.Transform{a,b,c,d,e,f}:
      L.finite(a) && L.finite(b) && L.finite(c) && L.finite(d) && L.finite(e) && L.finite(f)

type State is Data:
  State{rest: String, transform: P.Transform}

def arguments(name: String, slice: X.Slice, previous: P.Transform) -> Result<&2,&1,String,State>:
  match slice:
    case X.Slice{value,rest,_}:
      do Result<&2,&1,String,State>:
        ns : +List<F32> <- L.numbers(value)
        t : P.Transform <- operation(name,ns)
        +composed : P.Transform = P.compose(previous,t)
        u : Unit <- L.require(valid(composed),"non-finite or excessive SVG transform")
        return State{L.trim(rest),composed}

def parenthesized(name: String, s: String, previous: P.Transform) -> Result<&2,&1,String,State>:
  match s:
    case SCon{Chr{40},t}:
      do Result<&2,&1,String,State>:
        slice : X.Slice <- X.quoted_loop(65536n,41,Done{X.Slice{SNil{},t,False{}}})
        arguments(name,slice,previous)
    case _:
      Fail{"expected '(' in SVG transform"}

def named(slice: X.Slice, previous: P.Transform) -> Result<&2,&1,String,State>:
  match slice:
    case X.Slice{name,rest,_}:
      parenthesized(name,L.trim(rest),previous)

def step(state: State) -> Result<&2,&1,String,State>:
  match state:
    case State{rest,t}:
      do Result<&2,&1,String,State>:
        name : X.Slice <- X.word(rest)
        named(name,t)

def loop(fuel: Nat, result: Result<&2,&1,String,State>) -> Result<&2,&1,String,P.Transform>:
  match fuel result:
    case _ Fail{e}:
      Fail{e}
    case _ Done{State{SNil{},t}}:
      Done{t}
    case 0n Done{_}:
      Fail{"SVG transform operation limit (64)"}
    case 1n+p Done{state}:
      loop(p,step(state))

def parse(data: String) -> Result<&2,&1,String,P.Transform>:
  loop(64n,Done{State{L.trim(data),P.identity()}})
