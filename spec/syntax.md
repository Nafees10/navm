# NaVM syntax

_Note that you don't need to use this syntax to write NaVM progrms. You can
programmatically construct programs_ 

## Statements

A statement is a single line. A statement in NaVM can be:

* Empty or whitespace
* Label
* Instruction + optional args
* Label + Instruction + optional args

## Instructions

Instructions are written as instructionName followed by any argument(s),
separeted by whitespace. The instructionName is case sensitive.

```
instructionName		argument		argument
```

## Labels

Label names are case sensitive as well.

```
SomeLabel:
			SomeInstruction
			MoreInstructions
OtherLabel: AnotherInstruction		withSomeArg		andAnotherArg		# comment
			Jump SomeLabel
```

## Whitespace

Whitespace can be either tab(s) or space(s), and is ignored.
At least 1 character of whitespace is necessary between labels, instruction
names, and arguments.

## Instruction Arguments

An instruction can have any number of arguments. These can be of following
types:

* Integer - signed integer (`ptrdiff_t`)
* Double - a float
* Boolean - true (a non zero ubyte), or false (0)
* String - a string, enclosed between `"`
* Address - an address to a data, see below for details.
* Label - position in code. Written as `@LabelName`.

### Address

This is translated to the data location, and can be written in a number of
ways. Assuming this code:

```
start:	add2	50	250
		store	<ADDRESS>
```

In this case, `<ADDRESS>` can be written as:

* `@+0` to point to `50`
* `@+1` to point to `250`
* `@+2` to point to itself
* `@start+0` to point to `50`
* `@start+1` to point to `250`
* `@start+2` to point to itself

### Strings

These are written like: `"someString"`.

The back-slash character can be used to include characters like `"` or tab by
doing: `"tab: \t, quotationMark: \""`

### Characters
These are written like: `'c'`.

### Hexadecimal Integer
These are read as of type Integer, and are written like: `0xFFF`, where `FFF`
is the number.

### Binary Integer
Integer can be written in binary as: `0b1111`, where `1111` is the number.

## Comments
Anything following a `#` (including the `#`) are considered comments and are
ignored:

```
	#comment
	someInstruction someArgument # this is a comment
```
