import Base
import ./lex.bend as L
import ./path.bend as P

type State is Data:
  State{tokens: +List<L.Token>, reversed: +List<P.Segment>, current: P.Point, start: P.Point, control: P.Point, previous: U32, command: U32, begun: Bool}

def plus(a: P.Point, b: P.Point) -> P.Point:
  match a b:
    case P.Point{ax,ay} P.Point{bx,by}:
      P.Point{(ax + bx : F32),(ay + by : F32)}

def relative(p: P.Point, origin: P.Point, lower: Bool) -> P.Point:
  match lower:
    case False{}:
      p
    case True{}:
      plus(origin,p)

def reflect(p: P.Point, c: P.Point, use_control: Bool) -> P.Point:
  match p c use_control:
    case P.Point{x,y} _ False{}:
      P.Point{x,y}
    case P.Point{x,y} P.Point{cx,cy} True{}:
      P.Point{(2.0 * x - cx : F32),(2.0 * y - cy : F32)}

def push(tokens: +List<L.Token>, acc: +List<P.Segment>, +current: P.Point, start: P.Point, control: P.Point, previous: U32, command: U32, segment: P.Segment) -> State:
  State{tokens,segment <> acc,current,start,control,previous,command,True{}}

def move(tokens: +List<L.Token>, acc: +List<P.Segment>, +p: P.Point, +command: U32) -> State:
  push(tokens,acc,p,p,p,77,U32.sub(command,1),P.MoveTo{p})

def line(tokens: +List<L.Token>, acc: +List<P.Segment>, +p: P.Point, start: P.Point, command: U32) -> State:
  push(tokens,acc,p,start,p,76,command,P.Line{p})

def quad(tokens: +List<L.Token>, acc: +List<P.Segment>, +p: P.Point, start: P.Point, +c: P.Point, command: U32) -> State:
  push(tokens,acc,p,start,c,81,command,P.Quad{c,p})

def cubic(tokens: +List<L.Token>, acc: +List<P.Segment>, +p: P.Point, start: P.Point, c1: P.Point, +c2: P.Point, command: U32) -> State:
  push(tokens,acc,p,start,c2,67,command,P.Cubic{c1,c2,p})

def horizontal(current: P.Point, +value: F32, lower: Bool) -> P.Point:
  match current:
    case P.Point{+x,y}:
      P.Point{Bool.pick(F32,lower,F32.add(x,value),value),y}

def vertical(current: P.Point, +value: F32, lower: Bool) -> P.Point:
  match current:
    case P.Point{x,+y}:
      P.Point{x,Bool.pick(F32,lower,F32.add(y,value),value)}

def arguments(+kind: U32, tokens: +List<L.Token>, acc: +List<P.Segment>, +current: P.Point, +start: P.Point, control: P.Point, previous: U32, +command: U32, +lower: Bool) -> Result<&2,&1,String,State>:
  match kind tokens:
    case 77 L.Number{x} <> L.Number{y} <> rest:
      Done{move(rest,acc,relative(P.Point{x,y},current,lower),command)}
    case 76 L.Number{x} <> L.Number{y} <> rest:
      Done{line(rest,acc,relative(P.Point{x,y},current,lower),start,command)}
    case 72 L.Number{x} <> rest:
      Done{line(rest,acc,horizontal(current,x,lower),start,command)}
    case 86 L.Number{y} <> rest:
      Done{line(rest,acc,vertical(current,y,lower),start,command)}
    case 81 L.Number{x1} <> L.Number{y1} <> L.Number{x} <> L.Number{y} <> rest:
      Done{quad(rest,acc,relative(P.Point{x,y},current,lower),start,relative(P.Point{x1,y1},current,lower),command)}
    case 84 L.Number{x} <> L.Number{y} <> rest:
      c = reflect(current,control,U32.is_eq(previous,81))
      Done{quad(rest,acc,relative(P.Point{x,y},current,lower),start,c,command)}
    case 67 L.Number{x1} <> L.Number{y1} <> L.Number{x2} <> L.Number{y2} <> L.Number{x} <> L.Number{y} <> rest:
      Done{cubic(rest,acc,relative(P.Point{x,y},current,lower),start,relative(P.Point{x1,y1},current,lower),relative(P.Point{x2,y2},current,lower),command)}
    case 83 L.Number{x2} <> L.Number{y2} <> L.Number{x} <> L.Number{y} <> rest:
      c1 = reflect(current,control,U32.is_eq(previous,67))
      Done{cubic(rest,acc,relative(P.Point{x,y},current,lower),start,c1,relative(P.Point{x2,y2},current,lower),command)}
    case _ _:
      Fail{"missing/invalid arguments for SVG path command " ++ U32.show(kind)}

def dispatch(+command: U32, tokens: +List<L.Token>, acc: +List<P.Segment>, current: P.Point, +start: P.Point, control: P.Point, previous: U32, begun: Bool) -> Result<&2,&1,String,State>:
  +kind = U32.and(command,223)
  do Result<&2,&1,String,State>:
    u : Unit <- L.require(begun || U32.is_eq(kind,77), "SVG path must begin with moveto")
    arguments(kind,tokens,acc,current,start,control,previous,command,(command >= 97 : U32))

def command_step(command: U32, tokens: +List<L.Token>, acc: +List<P.Segment>, current: P.Point, +start: P.Point, control: P.Point, previous: U32, begun: Bool) -> Result<&2,&1,String,State>:
  match command:
    case 90:
      do Result<&2,&1,String,State>:
        u : Unit <- L.require(begun,"closepath before moveto")
        return push(tokens,acc,start,start,start,90,0,P.ClosePath{})
    case 122:
      do Result<&2,&1,String,State>:
        u : Unit <- L.require(begun,"closepath before moveto")
        return push(tokens,acc,start,start,start,90,0,P.ClosePath{})
    case 65:
      Fail{"SVG elliptical arc A/a is unsupported"}
    case 97:
      Fail{"SVG elliptical arc A/a is unsupported"}
    case c:
      dispatch(c,tokens,acc,current,start,control,previous,begun)

def step(state: State) -> Result<&2,&1,String,State>:
  match state:
    case State{L.Letter{c} <> rest,acc,current,start,control,previous,_,begun}:
      command_step(c,rest,acc,current,start,control,previous,begun)
    case State{tokens,acc,current,start,control,previous,command,begun}:
      dispatch(command,tokens,acc,current,start,control,previous,begun)

def parse_loop(fuel: Nat, rule: P.FillRule, result: Result<&2,&1,String,State>) -> Result<&2,&1,String,P.Path>:
  match fuel result:
    case _ Fail{e}:
      Fail{e}
    case _ Done{State{Nil{},acc,_,_,_,_,_,_}}:
      Done{P.Path{List.reverse(&2,P.Segment,acc),rule}}
    case 0n Done{_}:
      Fail{"SVG path segment limit (8192)"}
    case 1n+p Done{state}:
      parse_loop(p,rule,step(state))

def parse(data: String, rule: P.FillRule) -> Result<&2,&1,String,P.Path>:
  do Result<&2,&1,String,P.Path>:
    tokens : +List<L.Token> <- L.tokens(data)
    parse_loop(8192n,rule,Done{State{tokens,Nil{},P.Point{0.0,0.0},P.Point{0.0,0.0},P.Point{0.0,0.0},0,0,False{}}})
