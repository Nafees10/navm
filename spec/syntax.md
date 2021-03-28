# NaVM syntax

_Note that you don't need to use this syntax to execute byte code using NaVM. You can programmatically construct programs_ 

## Instructions
Instructions are executed from top to bottom.
They are **not** case sensitive, and are written like:  
```
	instructionName someArgument
	anotherInstruction
```

## Instruction Arguments

An instruction can have any number of arguments (`<128`). These can be of following types:

* Literal - Any type of data (string, character, double, integer, positive integer, boolean)
* Integer - Positive or negative (or zero) integer
* UInteger - `>0` integer
* Boolean - true (a non zero integer), or false (0, integer)
* Label - Name of a Label. This is replaced with the index (integer) of that label stored in `_labels` array in NaVM when bytecode is loaded.
* Address - Address to an element on stack. This can be absolute address, or relative, depending on instruction

If an instruction requires an argument of type `Literal`, then it will accept `Integer`, `UInteger`, and `Boolean` as well.

### String Literals
These are written like: `"someString"`.  
The back-slash character can be used to include characters like `"` or tab by doing: `"tab: \t, quotationMark: \""`

### Character Literals
These are written like: `'c'`.  

### Hexadecimal Literals
These are read as of type UInteger, and are written like: `0xFFF`, where `FFF` is the number.

### Binary Literals
UInteger can be written in binary as: `0B1111`, where `1111` is the number.

### Address
Address is written like: `@0`, this point to the `0`th element, which may be relative to another address depending on instruction it is used with.
The instruction receives this address as an integer, in this case, `0`.

## Comments
Anything following a `#` (including the `#`) are considered comments and are ignored:  

```
	#comment
	someInstruction someArgument # this is a comment
```

## Labels
These are used to specify from where execution can start from, or jump to.  
They are also not case sensitive. And are written like:

```
SomeLabel:
			SomeInstruction
			MoreInstructions
OtherLabel: AnotherInstruction		withSomeArg		andAnotherArg	# a comment
```

## Whitespace
Whitespace can be either tab(s) or space(s), and is ignored.  
At least 1 character of whitespace is necessary between labels, instruction names, and arguments.
