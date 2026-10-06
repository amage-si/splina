import Base

def read_finish(pair: File & Result<&1,&1,U32 & String,String>) -> IO(String):
  (file,result) = pair
  do IO<String>:
    File.close(file)
    IO.pass(String,result)

def read(path: String) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    result : File & Result<&1,&1,U32 & String,String> <- File.read(file,262145)
    read_finish(result)

def pass(-A: Type, result: Result<&2,&1,String,A>) -> IO(A):
  match result:
    case Fail{e}:
      IO.die(A,1,e)
    case Done{x}:
      IO.pure(A,x)
