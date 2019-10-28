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
FunctionID#comment
StackLength
	FirstInstruction [InstructionArgument0] [Argument1]
	SecondInstruction # comment
	ThridInstruction
# comment
	FourthInstruction
AnotherFunctionID
StackLength
	...

```

The bytecode is divided into functions.  
Each function definition begins with the function id (this is a positive integer), and the required stack length.  
Both of these are to be on a separate line, and the lines cannot begin with whitespace.  
After that, each line is an instruction or a comment.  

Instructions are written in either of these ways:  
`Tab %instruction% %arguments%`  
The a tab is used to indent, spaces are not allowed.

### Instructions

#### Math operators
