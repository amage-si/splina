import Base
import ../main.bend as S
import ../file.bend as SF
import ../render.bend as R
import ../../Ocula/main.bend as O
import ../../Ocula/file.bend as OF
import ../../Ocula/pixels.bend as Pixels
import ../../Chromi/main.bend as C
import ../../Chromi/geometry.bend as G
import ../../Ankra/main.bend as A

# Run from the Splina repository root: file paths are relative to the working
# directory. The PNG is the kitty terminal icon installed by the system; it is
# not part of this repository.

def blit(image: Pixels.Raster, canvas: C.Canvas) -> C.Canvas:
  match image:
    case Pixels.Raster{+w,+h,pixels}:
      C.blit_rgba(canvas,40.0,56.0,w,h,Pixels.packed_pixels(Pixels.Raster{w,h,pixels}))

def draw(image: Pixels.Raster, svg: S.Svg) -> IO(Image):
  c = C.new(640,368,1.0,219422463)
  c = C.fill_rect(c,G.Rect{24.0,24.0,288.0,320.0},354033919)
  c = C.fill_rect(c,G.Rect{328.0,24.0,288.0,320.0},354033919)
  c = C.fill_rect(c,G.Rect{40.0,40.0,256.0,4.0},1089715967)
  c = C.fill_rect(c,G.Rect{344.0,40.0,256.0,4.0},4284128255)
  c = C.fill_rect(c,G.Rect{40.0,56.0,256.0,256.0},522661887)
  c = C.fill_rect(c,G.Rect{40.0,56.0,128.0,128.0},825572863)
  c = C.fill_rect(c,G.Rect{168.0,184.0,128.0,128.0},825572863)
  c = blit(image,c)
  do IO<Image>:
    c : C.Canvas <- SF.pass(C.Canvas,R.draw(svg,c,360.0,72.0,224.0))
    IO.pass(Image,C.finish(c))

def tick(batch: A.Batch, state: U32) -> IO(A.Step<U32>):
  IO.pure(A.Step<U32>,A.Keep{state})

def main() -> IO(Unit):
  do IO<Unit>:
    png : +List<U32> <- OF.read("/usr/share/pixmaps/kitty.png")
    image : Pixels.Raster <- SF.pass(Pixels.Raster,O.decode_png(png))
    source : String <- SF.read("fixtures/heart-fill.svg")
    svg : S.Svg <- SF.pass(S.Svg,S.parse_svg_with_color(source,4284128255))
    frame : Image <- draw(image,svg)
    IO.print("Ocula: original Kitty PNG 256x256 RGBA8; Splina: original Bootstrap heart SVG; Dithra + Chromi + Ankra; closes after 15 seconds")
    A.run(~U32,~tick,"AMAGE Eco - Ocula PNG / Splina SVG - Bend 2",640,368,900n,0,frame)
    IO.print("demo closed")
