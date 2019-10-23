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
0	FirstInstruction [InstructionArgument0] [Argument1]
1	SecondInstruction # comment
2	ThridInstruction
# comment
3	FourthInstruction
AnotherFunctionID
StackLength
1	...

```

The bytecode is divided into functions.  
Each function definition begins with the function id (this is a positive integer), and the required stack length.  
Both of these are to be on a separate line, and the lines cannot begin with whitespace.  
After that, each line is an instruction or a comment.  

Instructions are written in either of these ways:  
`%number% Tab %instruction% %arguments%`  
or:  
`Tab %instruction% %arguments%`  
The tab must be a tab, spaces are not allowed.

### Instructions

#### Math operators
