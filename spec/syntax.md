# NaVM syntax

_Note that you **don't** necessarily need to use this syntax to execute byte code using NaVM. You can programmatically construct programs using the `NaFunction` struct._  

## Comments
Anything following a `#` (including the `#`) are considered comments and are ignored:  

```
	# this is a comment
```

## Functions
There are 2 types of Functions:  

1. OnLoad function - Executed after byte code is loaded (i.e before any other function is executed). Use this for initializing.
2. Regular functions - Can be called by NaVM and from within byte code as well.
  
Each byte code can have maximum of 1 OnLoad function, or none. An OnLoad function has no ID, and as such, can not be called from within byte code.  

Each regular function has a ID number. This cannot be manually assigned. The first regular function defined in a byte code is assigned ID=0, next is ID=1 and so on.  

The required stack length must also be provided in function definition, as NaVM uses fixed-length arrays as a stack.  

### Defining Functions

A function that needs stack length of 5 elements would be defined like:  

```
def [optional, function-type] 5
	# First instruction
	# Second instruction
```

function type is optional, by default, all functions are regular function. To write an OnLoad functions:  

```
def onLoad 5
	# First Instruction
	# 2nd
	# ...
```

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

