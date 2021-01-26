# NaVM syntax

_Note that you don't need to use this syntax to execute byte code using NaVM. You can programmatically construct programs as the `NaBytecode` class._  

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
	someJumpPosition:
	# instructions to be repeated
	jump someJumpPosition
```

Jump positions are also **not** case sensitive.   
A jump position must be followed by at least 1 instruction, i.e: a jump position cannot be the last line in byte code.

## Whitespace
Whitespace can be either tab(s) or space(s), and is ignored.
