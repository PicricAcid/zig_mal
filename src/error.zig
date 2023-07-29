const std = @import("std");

pub const MalError = error{
    SyntaxError,
    ParseError,
    PrintError,
    HashMapError,
    FuncArgError,
    EnvFindError,
    EnvDefineError,
    LambdaDefineError,
    LambdaArgsError,
    ApplyFunctionError,
    DataTypeError,
    OutOfMemory,
    AccessDenied,
    BrokenPipe,
    ConnectionResetByPeer,
    InputOutput,
    OperationAborted,
    SystemResources,
    Unexpected,
    WouldBlock,
    ConnectionTimedOut,
    IsDir,
    NotOpenForReading,
    EndOfStream,
    InvalidCharacter,
    Overflow,
};