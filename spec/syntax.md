# NaVM syntax

_Note that you don't need to use this syntax to write NaVM progrms. You can programmatically construct programs_ 

## Instructions
Instructions are executed from top to bottom.
They are **not** case sensitive, and are written like:  
```
instructionName     argument   argument
```

instructionName can only contain alphabets (lowercase and uppercase).

## Labels
These are used to specify from where execution can start from, or jump to.  
They are also not case sensitive. And are written like:

```
SomeLabel:
			SomeInstruction
			MoreInstructions
OtherLabel: AnotherInstruction		withSomeArg	  andAnotherArg   # comment
			Jump SomeLabel
```

## Whitespace
Whitespace can be either tab(s) or space(s), and is ignored.  
At least 1 character of whitespace is necessary between labels, instruction names, and arguments.

## Instruction Arguments

An instruction can have any number of arguments. These can be of following types:

* Integer - signed integer (`ptrdiff_t`)
* Double - a float
* Address - an address to an argument, this can be written in a number of ways, see below.
* Boolean - true (a non zero ubyte), or false (0)
* String - a string, enclosed between `"`
* Label - Name of a Label. This is replaced with the index (integer) of that label stored in `_labels` array in NaVM when bytecode is loaded.

### Address
This is translated to the argument index (integer), but can be written in a number of ways.  
Assuming this code:   
```
start:	add2	50	250
		store	<ADDRESS>
```
In this case, `<ADDRESS>` can be written as:  

* `@0` to point to `50`
* `@1` to point to `250`
* `@2` to point to itself
* `@start` or `@start,0` to point to `50`
* `@start,1` to point to `250`
* `@start,2` to point to itself

**There must be no whitespace before/after the comma or `@` when writing address**


### Strings
These are written like: `"someString"`.  
The back-slash character can be used to include characters like `"` or tab by doing: `"tab: \t, quotationMark: \""`

### Characters
These are written like: `'c'`.  

### Hexadecimal Integer
These are read as of type Integer, and are written like: `0xFFF`, where `FFF` is the number.

### Binary Integer
Integer can be written in binary as: `0B1111`, where `1111` is the number.

## Comments
Anything following a `#` (including the `#`) are considered comments and are ignored:  

```
	#comment
	someInstruction someArgument # this is a comment
```
