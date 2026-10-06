import Base

# Coordinates are logical screen units: x right, y down.
type Point is Data:
  Point{x: F32, y: F32}

type Segment is Data:
  MoveTo{to: Point}
  Line{to: Point}
  Quad{control: Point, to: Point}
  Cubic{control1: Point, control2: Point, to: Point}
  ClosePath{}

type FillRule is Data:
  NonZero{}
  EvenOdd{}

type Path is Data:
  Path{segments: +List<Segment>, rule: FillRule}

type Transform is Data:
  Transform{a: F32, b: F32, c: F32, d: F32, e: F32, f: F32}

def identity() -> Transform:
  Transform{1.0, 0.0, 0.0, 1.0, 0.0, 0.0}

def translate(x: F32, y: F32) -> Transform:
  Transform{1.0, 0.0, 0.0, 1.0, x, y}

def scale(x: F32, y: F32) -> Transform:
  Transform{x, 0.0, 0.0, y, 0.0, 0.0}

def rotate(+radians: F32) -> Transform:
  +s = F32.sin(radians)
  +c = F32.cos(radians)
  Transform{c, s, F32.neg(s), c, 0.0, 0.0}

def point(t: Transform, p: Point) -> Point:
  match t p:
    case Transform{a,b,c,d,e,f} Point{+x,+y}:
      Point{(a * x + c * y + e : F32), (b * x + d * y + f : F32)}

# compose(outer, inner) applies inner first.
def compose(outer: Transform, inner: Transform) -> Transform:
  match outer inner:
    case Transform{+a,+b,+c,+d,e,f} Transform{+g,+h,+i,+j,+k,+l}:
      Transform{(a * g + c * h : F32), (b * g + d * h : F32), (a * i + c * j : F32), (b * i + d * j : F32), (a * k + c * l + e : F32), (b * k + d * l + f : F32)}

def segment(+t: Transform, s: Segment) -> Segment:
  match s:
    case MoveTo{p}:
      MoveTo{point(t, p)}
    case Line{p}:
      Line{point(t, p)}
    case Quad{c,p}:
      Quad{point(t,c),point(t,p)}
    case Cubic{c1,c2,p}:
      Cubic{point(t,c1),point(t,c2),point(t,p)}
    case ClosePath{}:
      ClosePath{}

def segments(xs: +List<Segment>, +t: Transform) -> +List<Segment>:
  match xs:
    case Nil{}:
      Nil{}
    case s <> rest:
      segment(t,s) <> segments(rest,t)

def transform(path: Path, t: Transform) -> Path:
  match path:
    case Path{ss,rule}:
      Path{segments(ss,t),rule}

def lerp(a: Point, b: Point, +t: F32) -> Point:
  match a b:
    case Point{ax,ay} Point{bx,by}:
      Point{F32.lerp(ax,bx,t),F32.lerp(ay,by,t)}

def midpoint(a: Point, b: Point) -> Point:
  lerp(a,b,0.5)

def quadratic(a: Point, +b: Point, c: Point, +t: F32) -> Point:
  lerp(lerp(a,b,t),lerp(b,c,t),t)

def cubic(a: Point, +b: Point, +c: Point, d: Point, +t: F32) -> Point:
  quadratic(lerp(a,b,t),lerp(b,c,t),lerp(c,d,t),t)

def finite(+v: F32) -> Bool:
  (v >= F32.neg(1000000.0) : F32) && (v <= 1000000.0 : F32)

def valid_point(p: Point) -> Bool:
  match p:
    case Point{x,y}:
      finite(x) && finite(y)

def valid_segment(s: Segment) -> Bool:
  match s:
    case MoveTo{p}:
      valid_point(p)
    case Line{p}:
      valid_point(p)
    case Quad{c,p}:
      valid_point(c) && valid_point(p)
    case Cubic{c1,c2,p}:
      valid_point(c1) && valid_point(c2) && valid_point(p)
    case ClosePath{}:
      True{}

def valid(path: Path) -> Bool:
  match path:
    case Path{ss,_}:
      List.all(~&2,~Segment,~valid_segment,ss)
