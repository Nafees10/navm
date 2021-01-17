# NaVM syntax

_Note that you don't need to use this syntax to execute byte code using NaVM. You can programmatically construct programs as the `NaBytecode` struct._  

## Instructions
Instructions are executed from top to bottom, and jumps can be used to jump to other instructions.  
An instruction can take maximum of 1 argument, or not take any at all.  
They are **not** case sensitive, and are written like:  
```
instructionName someArgument
anotherInstruction
```

## Comments
Anything following a `#` (including the `#`) are considered comments and are ignored:  

```
#comment
someInstruction someArgument # this is a comment
```

## Jumps
To use a jump instruction (see `spec/instructions.md`), you need a jump position. This is done like:  

```
# some instructions here
someJumpPosition:
# instructions to be repeated
# some instructions that act as a loop condition
jumpIf someJumpPosition
```

Jump positions are **not** case sensitive

## Whitespace
Whitespace can be either tab(s) or space(s), and is ignored, so whitespace is not necessary
