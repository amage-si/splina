import Base
import ./lex.bend as L

type Attr is Data:
  Attr{name: String, value: String}

type Tag is Data:
  Tag{name: String, attrs: +List<Attr>, closing: Bool, empty: Bool}

type TagRead is Data:
  TagRead{tag: Tag, rest: String}

type Slice is Data:
  Slice{reversed: String, rest: String, done: Bool}

def name_char(+c: U32) -> Bool:
  L.letter(c) || L.digit(c) || U32.is_eq(c,95) || U32.is_eq(c,45) || U32.is_eq(c,58)

def slice_char(h: Char, t: String, acc: String, keep: Bool) -> Slice:
  match keep:
    case True{}:
      Slice{SCon{h,acc},t,False{}}
    case False{}:
      Slice{acc,SCon{h,t},True{}}

def word_step(slice: Slice) -> Slice:
  match slice:
    case Slice{acc,SNil{},_}:
      Slice{acc,SNil{},True{}}
    case Slice{acc,SCon{Chr{+c},t},_}:
      slice_char(Chr{c},t,acc,name_char(c))

def word_loop(fuel: Nat, slice: Slice) -> Result<&2,&1,String,Slice>:
  match fuel slice:
    case _ Slice{+acc,rest,True{}}:
      do Result<&2,&1,String,Slice>:
        u : Unit <- L.require(Bool.not(String.is_empty(acc)),"expected XML name")
        return Slice{String.reverse(acc),rest,True{}}
    case 0n _:
      Fail{"XML name length limit (64)"}
    case 1n+p s:
      word_loop(p,word_step(s))

def word(s: String) -> Result<&2,&1,String,Slice>:
  word_loop(65n,Slice{SNil{},s,False{}})

def quoted_char(+c: U32, t: String, acc: String, quote: U32, ended: Bool) -> Result<&2,&1,String,Slice>:
  match ended:
    case True{}:
      Done{Slice{String.reverse(acc),t,True{}}}
    case False{}:
      do Result<&2,&1,String,Slice>:
        u : Unit <- L.require(U32.is_ne(c,38) && U32.is_ne(c,60), "XML entities and '<' in attributes are unsupported")
        return Slice{SCon{Chr{c},acc},t,False{}}

def quoted_step(slice: Slice, +quote: U32) -> Result<&2,&1,String,Slice>:
  match slice:
    case Slice{_,SNil{},_}:
      Fail{"unterminated XML attribute"}
    case Slice{acc,SCon{Chr{+c},t},_}:
      quoted_char(c,t,acc,quote,U32.is_eq(c,quote))

def quoted_loop(fuel: Nat, +quote: U32, result: Result<&2,&1,String,Slice>) -> Result<&2,&1,String,Slice>:
  match fuel result:
    case _ Fail{e}:
      Fail{e}
    case _ Done{Slice{value,rest,True{}}}:
      Done{Slice{value,rest,True{}}}
    case 0n Done{_}:
      Fail{"XML attribute length limit"}
    case 1n+p Done{slice}:
      quoted_loop(p,quote,quoted_step(slice,quote))

def quoted(s: String) -> Result<&2,&1,String,Slice>:
  match s:
    case SCon{Chr{34},t}:
      quoted_loop(65536n,34,Done{Slice{SNil{},t,False{}}})
    case SCon{Chr{39},t}:
      quoted_loop(65536n,39,Done{Slice{SNil{},t,False{}}})
    case _:
      Fail{"XML attributes require single or double quotes"}

def attr_equal(s: String) -> Result<&2,&1,String,Slice>:
  match s:
    case SCon{Chr{61},t}:
      quoted(L.trim(t))
    case _:
      Fail{"expected '=' after XML attribute name"}

type TagState is Data:
  TagState{rest: String, name: String, attrs: +List<Attr>, closing: Bool}
  TagDone{value: TagRead}

def attr_push(name: String, value: Slice, tag: String, attrs: +List<Attr>, closing: Bool) -> TagState:
  match value:
    case Slice{value,rest,_}:
      TagState{rest,tag,Attr{name,value} <> attrs,closing}

def has_attr(attrs: +List<Attr>, +name: String) -> Bool:
  match attrs:
    case Nil{}:
      False{}
    case Attr{key,_} <> t:
      String.eq(key,name) || has_attr(t,name)

def attr_name(slice: Slice, tag: String, +attrs: +List<Attr>, closing: Bool) -> Result<&2,&1,String,TagState>:
  match slice:
    case Slice{+name,rest,_}:
      do Result<&2,&1,String,TagState>:
        u : Unit <- L.require(Bool.not(has_attr(attrs,name)),"duplicate XML attribute " ++ name)
        value : Slice <- attr_equal(L.trim(rest))
        return attr_push(name,value,tag,attrs,closing)

def tag_content(s: String, tag: String, attrs: +List<Attr>, +closing: Bool, separated: Bool) -> Result<&2,&1,String,TagState>:
  match s:
    case SCon{Chr{62},t}:
      Done{TagDone{TagRead{Tag{tag,List.reverse(&2,Attr,attrs),closing,False{}},t}}}
    case SCon{Chr{47},SCon{Chr{62},t}}:
      do Result<&2,&1,String,TagState>:
        u : Unit <- L.require(Bool.not(closing),"closing XML tag cannot be self-closing")
        return TagDone{TagRead{Tag{tag,List.reverse(&2,Attr,attrs),False{},True{}},t}}
    case rest:
      do Result<&2,&1,String,TagState>:
        u : Unit <- L.require(separated && Bool.not(closing), "missing whitespace between XML attributes or malformed closing tag")
        name : Slice <- word(rest)
        attr_name(name,tag,attrs,closing)

def tag_step(state: TagState) -> Result<&2,&1,String,TagState>:
  match state:
    case TagDone{v}:
      Done{TagDone{v}}
    case TagState{SNil{},_,_,_}:
      Fail{"unterminated XML tag"}
    case TagState{SCon{Chr{+c},t},name,attrs,closing}:
      tag_content(L.trim(SCon{Chr{c},t}),name,attrs,closing,L.space(c))

def tag_loop(fuel: Nat, result: Result<&2,&1,String,TagState>) -> Result<&2,&1,String,TagRead>:
  match fuel result:
    case _ Fail{e}:
      Fail{e}
    case _ Done{TagDone{v}}:
      Done{v}
    case 0n Done{_}:
      Fail{"XML attribute count limit (64)"}
    case 1n+p Done{state}:
      tag_loop(p,tag_step(state))

def named(slice: Slice, closing: Bool) -> Result<&2,&1,String,TagRead>:
  match slice:
    case Slice{name,rest,_}:
      tag_loop(65n,Done{TagState{rest,name,Nil{},closing}})

def opening(s: String) -> Result<&2,&1,String,TagRead>:
  match s:
    case SCon{Chr{47},t}:
      do Result<&2,&1,String,TagRead>:
        name : Slice <- word(t)
        named(name,True{})
    case SCon{Chr{33},_}:
      Fail{"XML declarations, comments and DTDs are unsupported"}
    case SCon{Chr{63},_}:
      Fail{"XML processing instructions are unsupported"}
    case rest:
      do Result<&2,&1,String,TagRead>:
        name : Slice <- word(rest)
        named(name,False{})

def tag(s: String) -> Result<&2,&1,String,TagRead>:
  match s:
    case SCon{Chr{60},t}:
      opening(t)
    case _:
      Fail{"expected SVG tag; text content is unsupported"}

def read(s: String) -> Result<&2,&1,String,TagRead>:
  tag(L.trim(s))
