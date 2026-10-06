import Base

type Token is Data:
  Number{value: F32}
  Letter{code: U32}

def require(ok: Bool, message: String) -> Result<&2, &1, String, Unit>:
  match ok:
    case True{}:
      Done{Unit{}}
    case False{}:
      Fail{message}

# Bounded name tables avoid large structural string-pattern decision trees.
def name_id(names: +List<String>, +target: String, +index: U32) -> U32:
  match names:
    case Nil{}:
      0
    case head <> rest:
      Bool.pick(U32,String.eq(head,target),index,name_id(rest,target,U32.inc(index)))

def finite(+x: F32) -> Bool:
  (x >= F32.neg(1000000.0) : F32) && (x <= 1000000.0 : F32)

def space(+c: U32) -> Bool:
  U32.is_eq(c, 32) || U32.is_eq(c, 9) || U32.is_eq(c, 10) || U32.is_eq(c, 13)

def digit(+c: U32) -> Bool:
  (c >= 48 : U32) && (c <= 57 : U32)

def letter(+c: U32) -> Bool:
  ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32))

def xml_char(+c: U32) -> Bool:
  U32.is_eq(c,9) || U32.is_eq(c,10) || U32.is_eq(c,13) ||
    ((c >= 32 : U32) && (c <= 55295 : U32)) ||
    ((c >= 57344 : U32) && (c <= 65533 : U32)) ||
    ((c >= 65536 : U32) && (c <= 1114111 : U32))

def within(fuel: Nat, s: String) -> Bool:
  match fuel s:
    case _ SNil{}:
      True{}
    case 0n SCon{_,_}:
      False{}
    case 1n+p SCon{Chr{c},rest}:
      xml_char(c) && within(p,rest)

def trim_go(s: String, skip: Bool) -> String:
  match s skip:
    case SNil{} _:
      SNil{}
    case SCon{h,t} False{}:
      SCon{h,t}
    case SCon{h,SNil{}} True{}:
      SNil{}
    case SCon{h,SCon{Chr{+c},t}} True{}:
      trim_go(SCon{Chr{c},t},space(c))

def trim(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c},t}:
      trim_go(SCon{Chr{c},t},space(c))

type Scan is Data:
  Scanning{rest: String, reversed: String, mode: U32}
  Scanned{rest: String, value: F32}

def value_result(rest: String, r: Maybe<&2,F32>) -> Result<&2,&1,String,Scan>:
  match r:
    case None{}:
      Fail{"invalid SVG number"}
    case Some{+v}:
      do Result<&2,&1,String,Scan>:
        u : Unit <- require(finite(v), "SVG number outside finite +/-1000000 limit")
        return Scanned{rest,v}

def finish(rest: String, reversed: String, +mode: U32) -> Result<&2,&1,String,Scan>:
  do Result<&2,&1,String,Scan>:
    u : Unit <- require(U32.is_eq(mode,2) || U32.is_eq(mode,4) || U32.is_eq(mode,7), "incomplete SVG number")
    value_result(rest,F32.read(String.reverse(reversed)))

# Modes: start, sign, integer, leading dot, fraction, exponent, exponent sign, exponent digits.
def number_mode(mode: U32, c: U32, is_digit: Bool) -> U32:
  match mode c is_digit:
    case 0 _ True{}:
      2
    case 1 _ True{}:
      2
    case 2 _ True{}:
      2
    case 3 _ True{}:
      4
    case 4 _ True{}:
      4
    case _ _ True{}:
      7
    case 0 43 False{}:
      1
    case 0 45 False{}:
      1
    case 0 46 False{}:
      3
    case 1 46 False{}:
      3
    case 2 46 False{}:
      4
    case 2 101 False{}:
      5
    case 2 69 False{}:
      5
    case 4 101 False{}:
      5
    case 4 69 False{}:
      5
    case 5 43 False{}:
      6
    case 5 45 False{}:
      6
    case _ _ False{}:
      8

def number_next(rest: String, h: Char, reversed: String, old: U32, mode: U32) -> Result<&2,&1,String,Scan>:
  match mode:
    case 8:
      finish(SCon{h,rest},reversed,old)
    case next:
      Done{Scanning{rest,SCon{h,reversed},next}}

def scan_step(state: Scan) -> Result<&2,&1,String,Scan>:
  match state:
    case Scanned{rest,value}:
      Done{Scanned{rest,value}}
    case Scanning{SNil{},acc,mode}:
      finish(SNil{},acc,mode)
    case Scanning{SCon{Chr{+c},t},acc,+mode}:
      number_next(t,Chr{c},acc,mode,number_mode(mode,c,digit(c)))

def scan_loop(fuel: Nat, result: Result<&2,&1,String,Scan>) -> Result<&2,&1,String,Scan>:
  match fuel result:
    case _ Fail{e}:
      Fail{e}
    case _ Done{Scanned{s,v}}:
      Done{Scanned{s,v}}
    case 0n Done{_}:
      Fail{"SVG number length exceeds 64 characters"}
    case 1n+p Done{state}:
      scan_loop(p,scan_step(state))

type LexState is Data:
  LexState{rest: String, reversed: +List<Token>}

def lex_number(state: Scan, acc: +List<Token>) -> Result<&2,&1,String,LexState>:
  match state:
    case Scanned{s,v}:
      Done{LexState{s,Number{v} <> acc}}
    case _:
      Fail{"internal number scanner state"}

def lex_char(+c: U32, t: String, acc: +List<Token>, is_space: Bool, is_letter: Bool) -> Result<&2,&1,String,LexState>:
  match is_space is_letter:
    case True{} _:
      Done{LexState{t,acc}}
    case False{} True{}:
      Done{LexState{t,Letter{c} <> acc}}
    case False{} False{}:
      do Result<&2,&1,String,LexState>:
        state : Scan <- scan_loop(65n,Done{Scanning{SCon{Chr{c},t},SNil{},0}})
        lex_number(state,acc)

def lex_step(state: LexState) -> Result<&2,&1,String,LexState>:
  match state:
    case LexState{SNil{},acc}:
      Done{LexState{SNil{},acc}}
    case LexState{SCon{Chr{+c},t},acc}:
      lex_char(c,t,acc,space(c) || U32.is_eq(c,44),letter(c))

def lex_loop(fuel: Nat, result: Result<&2,&1,String,LexState>) -> Result<&2,&1,String,+List<Token>>:
  match fuel result:
    case _ Fail{e}:
      Fail{e}
    case _ Done{LexState{SNil{},acc}}:
      Done{List.reverse(&2,Token,acc)}
    case 0n Done{_}:
      Fail{"SVG token work limit"}
    case 1n+p Done{state}:
      lex_loop(p,lex_step(state))

def starts_number(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c},_}:
      digit(c) || U32.is_eq(c,43) || U32.is_eq(c,45) || U32.is_eq(c,46)

def comma_ok(c: U32, previous: Bool, rest: String) -> Bool:
  match c:
    case 44:
      previous && starts_number(trim(rest))
    case _:
      True{}

def commas(s: String, +previous: Bool) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c},+t}:
      comma_ok(c,previous,t) && commas(t,Bool.pick(Bool,space(c),previous,digit(c) || U32.is_eq(c,46)))

def tokens(+s: String) -> Result<&2,&1,String,+List<Token>>:
  do Result<&2,&1,String,+List<Token>>:
    u : Unit <- require(within(65536n,s), "SVG value exceeds 65536 characters or contains invalid XML characters")
    u : Unit <- require(commas(s,False{}), "invalid SVG comma separator")
    lex_loop(65537n,Done{LexState{s,Nil{}}})

def only_numbers(xs: +List<Token>, acc: +List<F32>) -> Result<&2,&1,String,+List<F32>>:
  match xs:
    case Nil{}:
      Done{List.reverse(&2,F32,acc)}
    case Number{v} <> rest:
      only_numbers(rest,v <> acc)
    case _:
      Fail{"expected SVG number list"}

def numbers(s: String) -> Result<&2,&1,String,+List<F32>>:
  do Result<&2,&1,String,+List<F32>>:
    ts : +List<Token> <- tokens(s)
    only_numbers(ts,Nil{})
