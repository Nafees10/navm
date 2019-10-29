# NaVM
A VM designed to be fast, intended for use in scripting languages.

---

## Getting Started
These instructions will get you a copy of NaVM with its very basic instuctions, and will show you how to add more functionality.

### Prerequisites
You need to have these present on your machine:

1. git
2. dub 
3. dlang compiler (recommended is dmd)

### Building
TODO

---

## Syntax
Although you do not need to actually write following this if you are using NaVM in a library, you can programmatically add instructions to functions, this still exists.  

The syntax is as follows:
```
def %StackLength% # this defiens function with function id = 0
	FirstInstruction [InstructionArgument0] [Argument1]
	SecondInstruction # comment
	ThridInstruction
# comment
	FourthInstruction
def %StackLength%# another function begins from here (id = 1)
FirstInstruction
Second
	...

```

The bytecode is divided into functions.  
Each function definition begins with the keyword `def`, followed by the required stack length (separate using whitespace).    
Function ID is automatically assigned, starting with 0. This is to avoid using assoc_arrays, to improve performace.  
Both of these are to be on a separate line.  
After that, each line is an instruction or a comment.  

Instructions are written in either of these ways:  
`Tab %instruction% %arguments%`  
or:  
`%instruction% %arguments%`  
Tabs or spaces can be used to indent, but indentation is not necesary.

### Instructions

#### Math operators
