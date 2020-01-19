# NaVM syntax

_Note that you **don't** necessarily need to use this syntax to execute byte code using NaVM. You can programmatically construct programs using the `NaFunction` struct._  

## Comments
Anything following a `#` (including the `#`) are considered comments and are ignored:  

```
	# this is a comment
```

## Defining functions
Each function has a ID number. This cannot be manually assigned. The first function defined in a byte code is assigned ID=0, next is ID=1 and so on.  

The required stack length must also be provided in function definition, as NaVM uses fixed-length arrays as a stack.  

A function that needs stack length of 5 elements would be defined like:  

```
def 5
	# First instruction
	# Second instruction
```

One thing to keep in mind is that although instruction names are not case sensitive, keywords are. So don't write `dEf` instead of `def`.

## Jumps
To use a jump instruction (see `spec/instructions.md`), you need a jump position. This is done like:  

```
def 5
	# some instructions here
	someJumpPosition:
	# instructions to be repeated
	# some instructions that act as a loop condition
	jumpIf someJumpPosition
```

In this example, `someJumpPosition` is the jump position. Jump position names are unique only inside the function. Meaning if you have used `someJumpPosition` in a function, you can not name another position that too, but outside that function, it's fine.

## Whitespace
Whitespace can be either tab(s) or spaces, and is ignored, so whitespace is not necessary

