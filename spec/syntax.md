# NaVM syntax

_Note that you **don't** necessarily need to use this syntax to execute byte code using NaVM. You can programmatically construct programs as the `NaFunction` struct._  

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

## Whitespace
Whitespace can be either tab(s) or space(s), and is ignored, so whitespace is not necessary
