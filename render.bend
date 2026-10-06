import Base
import ./main.bend as S
import ./path.bend as P
import ./geometry.bend as G
import ./style.bend as Style
import ./lex.bend as L
import ../Dithra/raster.bend as D
import ../Chromi/main.bend as C
import ../Chromi/geometry.bend as Rect

# Integration adapter. Rasterization is Dithra; compositing is Chromi.
def mask(r: Result<&2,&2,String,D.Mask>) -> Result<&2,&1,String,D.Mask>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{m}:
      Done{m}

def paint_mask(mask: D.Mask, canvas: C.Canvas, fill: U32) -> C.Canvas:
  match mask:
    case D.Mask{w,h,left,top,_,coverage}:
      C.blit_mask(canvas,left,top,w,h,coverage,fill)

def paint(shapes: +List<S.Shape>, canvas: C.Canvas, +t: P.Transform) -> Result<&2,&1,String,C.Canvas>:
  match shapes:
    case Nil{}:
      Done{canvas}
    case S.Shape{path,fill} <> rest:
      do Result<&2,&1,String,C.Canvas>:
        path : P.Path <- G.for_fill(P.transform(path,t))
        coverage : D.Mask <- mask(D.rasterize_screen(path,0.0))
        paint(rest,paint_mask(coverage,canvas,fill),t)

# Explicit xMidYMid meet mapping into a physical pixel square, canvas scale = 1.
def draw(svg: S.Svg, canvas: C.Canvas, +x: F32, +y: F32, +size: F32) -> Result<&2,&1,String,C.Canvas>:
  match svg:
    case S.Svg{_,_,Style.Box{vx,vy,+vw,+vh},shapes}:
      +scale = F32.min((size / vw : F32),(size / vh : F32))
      t = P.compose(P.translate((x + (size - vw * scale) * 0.5 : F32),(y + (size - vh * scale) * 0.5 : F32)),P.compose(P.scale(scale,scale),P.translate(F32.neg(vx),F32.neg(vy))))
      do Result<&2,&1,String,C.Canvas>:
        u : Unit <- L.require((size > 0.0 : F32) && (size <= 512.0 : F32),"demo SVG viewport limit 1..512 pixels")
        canvas : C.Canvas <- paint(shapes,C.clip_rect(canvas,Rect.Rect{x,y,size,size}),t)
        return C.reset_clip(canvas)
