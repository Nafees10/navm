# NaVM
A VM designed to be fast, intended for use in scripting languages.  
  
_It's sometimes written navm instead of NaVM, both are the same_

---

## Getting Started
These instructions will get you a copy of NaVM with its very basic instuctions, which will serve as a demo.  
Remember, NaVM is not built to be a standalone application, it's meant to be used as a library (originally built
for QScript, but everyone's free to use it).  

See `source/app.d` to see how to add external functions, and use it in your program.

### Prerequisites
You need to have these present on your machine:

1. dub 
2. dlang compiler (only dmd is tested)
3. Internet connection (for dub to fetch NaVM and its dependencies)

### Building
Run:
```
dub fetch navm
```
to download this package, and then run:
```
dub build navm -b=release
```
to fetch dependencies and build NaVM.  
Following this, you will have the NaVM binary with very basic functionality (to function as a demo).  

You can now run NaVM bytecode using:  
```
~/.dub/packages/navm-*/navm/navm path/to/bytecodefile
```


This binary also has 5 external functions:

* ID: 0, call using *`ExecuteFunctionExternal 0 n`* where n is number of integers to pop from stack and writeln(int) to terminal
* ID: 1, call using *`ExecuteFunctionExternal 1 n`* where n is number of doubles (floats) to pop from stack and writeln(double) to terminal
* ID: 2, call using *`ExecuteFunctionExternal 2 n`* where n is number of strings to pop from stack and write to terminal
* ID: 3, call using *`ExecuteFunctionExternal 3 n`* writes n number of newline characters to terminal
* ID: 4, call using *`ExecuteFunctionExternal 4 0`* reads a line from stdin, pushes it to stack
---

## Syntax
Although you do not need to actually write following this if you are using NaVM in a library, you can programmatically add instructions to functions, this still exists.(See `source/bytecodedefs.d : NaFunction`)  

The syntax is as follows:
```
def 20 # this defines function with function id = 0, which has space for 20 elements on stack
	FirstInstruction [InstructionArgument0] [Argument1]
	SecondInstruction # comment
	ThirdInstruction
# comment
	FourthInstruction
	
def 15 # another function begins from here (id = 1), which has space for 15 elements on stack
FirstInstruction		# Indentation is not necesarry, go crazy (i don't recommend it tho)
	SecondInstructions
	...

```

The bytecode is divided into functions.  
Each function definition begins with the keyword `def`, followed by the required stack length (separate using whitespace).    
Function ID is automatically assigned, starting with 0. This is to avoid using assoc_arrays, to improve performace.  
After that, each line is an instruction or a comment, or whitespace, until the next function definition is found.  

Instructions are written in either of these ways:  
`Tab %instruction% %arguments%`  
or:  
`%instruction% %arguments%`  
Tabs or spaces can be used to indent, but indentation is not necesary, and you can use more than 1 tab/space to indent.  
Instructions are not case sensitive, `ExecuteFunction` is the same as `eXeCuTeFuNcTiOn`.

## License
NaVM is licensed under the MIT License - see [LICENSE](LICENSE) for details

---

### Instructions

Here's a list of instructions that NaVM has out of the box. You can easily add more (Add name, argument count, and other info to `source/navm/bytecodedefs.d` and implement those instructions in `source/navm/navm.d`

#### Calling functions:

* _`ExecuteFunction [function id - integer>=0] [n - integer>=0]`_  
pops _`n`_ number of elements from stack. Calls a function defined in bytecode, pushes the elements in that function's stack in the same order they were. Pushes the return value from that function to stack.
* _`ExecuteFunctionExternal [function id - integer>=0] [n - integer>=0]`  
pops _`n`_ number of elements from stack. Calls an external function with the elements popped as arguments. Pushes the return value from that function to stack.
  
_Keep in mind that these functions push `NaData()` to stack if function did not return any meaningful data, so if you don't need to use the return value, or the function doesn't return meaningful data, follow these instructions with a `Pop` instruction._

#### Arithmetic operators

##### For integers
* _`MathAddInt`_  
Pops `A (integer)`, then `B (integer)`. Pushes `A + B (integer)` to stack.
* _`MathSubtractInt`_  
Pops `A (integer)`, then `B (integer)`. Pushes `A - B (integer)` to stack.
* _`MathMultiplyInt`_  
Pops `A (integer)`, then `B (integer)`. Pushes `A * B (integer)` to stack.
* _`MathDivideInt`_  
Pops `A (integer)`, then `B (integer)`. Pushes `A / B (integer)` to stack.
* _`MathModInt`_  
Pops `A (integer)`, then `B (integer)`. Pushes `A % B (integer)` to stack.

#### For floating point (double)
* _`MathAddDouble`_  
Pops `A (double)`, then `B (double)`. Pushes `A + B (double)` to stack.
* _`MathSubtractDouble`_  
Pops `A (double)`, then `B (double)`. Pushes `A - B (double)` to stack.
* _`MathMultiplyDouble`_  
Pops `A (double)`, then `B (double)`. Pushes `A * B (double)` to stack.
* _`MathDivideDouble`_  
Pops `A (double)`, then `B (double)`. Pushes `A / B (double)` to stack.
* _`MathModDouble`_  
Pops `A (double)`, then `B (double)`. Pushes `A % B (double)` to stack.

#### Comparison Operators
* _`IsSame`_  
Pops 2 values from stack, pushes `1 (integer)` to stack if both have same value, else, pushes `0 (integer)`.
* _`IsSameArray`_  
Pops 2 arrays from stack (arrays, not referece to array). Pushes `1 (integer)` to stack if both are same (length, and elements), else, pushes `0 (integer)`
* _`IsSameArrayRef`_  
Pops 2 references to arrays from stack. Pushes `1 (integer)` to stack if both are same (length, and elements), else, pushes `0 (integer)`
* _`IsGreaterInt`_  
Pops `A (integer)`, then `B (integer)`. Pushes `1 (integer)` if `A > B`, else, pushes `0 (integer)`
* _`IsGreaterSameInt`_  
Pops `A (integer)`, then `B (integer)`. Pushes `1 (integer)` if `A >= B`, else, pushes `0 (integer)`
* _`IsGreaterDouble`_  
Pops `A (double)`, then `B (double)`. Pushes `1 (integer)` if `A > B`, else, pushes `0 (integer)`
* _`IsGreaterSameDouble`_  
Pops `A (double)`, then `B (double)`. Pushes `1 (integer)` if `A >= B`, else, pushes `0 (integer)`
* _`Not`_  
Pops `A (integer)`. Pushes `!A`
* _`And`_  
Pops `A (integer)` and then `B (integer)`. Pushes `A && B`
* _`Or`_  
Pops `A (integer)` and then `B (integer)`. Pushes `A || B`

#### Stack
* _`Push [arg0 - any data type]`_  
Pushes `arg0` to stack
* _`PushFrom [index - integer>=0]`_  
Reads value at `index` on stack, pushes it. Value at `index` is not removed from stack.
* _`PushRefFrom [index - integer>=0]`_  
Pushes reference to value at `index` on stack.
* _`WriteTo [index - integer>=0]`_  
Pops a value from stack, writes it to `index` on stack.
* _`WriteToRef`_  
Pops a reference, then pops a value. Writes value to reference.
* _`Deref`_  
Pops a reference from stack. Pushes the value being referenced
* _`Pop`_  
Pops 1 value from stack

#### Jumps
* _`Jump [index - integer>=0]`_  
Jump execution to instruction at `index`. **Be careful using this, make sure you have used `Pop` to clear stack of unneeded elements**
* _`JumpIf [index - integer>=0]`_  
Pops integer from stack. If it is `1`, jumps execution to instruction at `index`. **Be careful using this, make sure you have used `Pop` to clear stack of unneeded elements**

#### Arrays
* _`MakeArray [n - integer>0]`_  
Pops `n` number of elements from stack, puts them in an array (in the order they were added to stack). Pushes array to stack.
* _`ReadElement`_  
Pops a reference to array, then an `index (integer)`. Pushes reference-to-element at `index` on array.
* _`ArrayLength`_  
Pops a reference to array. Pushes length of stack (integer) to stack.
* _`ArrayLengthSet`_  
Pops a reference to array, then `length (integer)`. Sets length of array to `length`
* _`Concatenate`_  
Pops an array `a1` _(not reference, array)_, then pops another array `a2`. Pushes new array `a1 ~ a2`.
* _`AppendElement`_  
Pops a reference to array, then an element. Appends element at end of array.
* _`AppendArrayRef`_  
Pops reference to array `r1`, pops another `r2`. Then does `*r1 = *r1 ~ *r2`
* _`AppendArray`_  
Pops reference to array `r1`, then pops an array _(not reference)_. Then does `*r1 = *r1 ~ r2`

#### Data type conversion
* _`IntToDouble`_  
Pops an integer from stack. Pushes a double with same value.
* _`IntToString`_  
Pops an integer from stack. Pushes a string representation of it.
* _`DoubleToInt`_  
Pops a double from stack. Pushes integer part of it (as a integer) to stack.
* _`DoubleToString`_  
Pops a double from stack. Pushes string representation of it.
* _`StringToInt`_  
Pops a string, reads integer from it, pushes the integer.
* _`StringToDouble`_  
Pops a string, reads a double from it, pushes the double.

#### Misc.
* _`ReturnVal`_  
Pops a value from stack, sets it as the return value of currently executing function. **Does NOT terminate execution**
* _`Terminate`_  
Terminates execution of function. **Must be called at end of function, or it'll segfault**