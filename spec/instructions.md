# NaVM Instructions

Here's a list of instructions that NaVM has out of the box. You can easily add more (Add name, argument count, and other info to `source/navm/bytecodedefs.d` and implement those instructions in `source/navm/navm.d`

## Calling functions:

* _`ExecuteFunction [function id - integer>=0] [n - integer>=0]`_  
pops _`n`_ number of elements from stack. Calls a function defined in bytecode, pushes the elements in that function's stack in the same order they were. Pushes the return value from that function to stack.
* _`ExecuteFunctionExternal [function id - integer>=0] [n - integer>=0]`_  
pops _`n`_ number of elements from stack. Calls an external function with the elements popped as arguments. Pushes the return value from that function to stack.
  
_Keep in mind that these functions push `NaData()` to stack if function did not return any meaningful data, so if you don't need to use the return value, or the function doesn't return meaningful data, follow these instructions with a `Pop` instruction._

## Arithmetic operators

### For integers
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

### For floating point (double)
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

---

## Comparison Operators
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

---

## Stack
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
* _`PopN [n - integer >= 0]`_  
Pops n number of values from stack

---

## Jumps
* _`Jump [jump position - string]`_  
Jump execution to instruction at `jump position`. **Be careful using this, make sure you have used `Pop` to clear stack of unneeded elements**
* _`JumpIf [jump position - string]`_  
Pops integer from stack. If it is `1`, jumps execution to instruction at `jump position`. **Be careful using this, make sure you have used `Pop` to clear stack of unneeded elements**

---

## Arrays
* _`MakeArray [n - integer>0]`_  
Pops `n` number of elements from stack, puts them in an array (in the order they were added to stack). Pushes array to stack.
* _`ArrayRefElement`_  
Pops a reference to array, then an `index (integer)`. Pushes reference-to-element at `index` on array.
* _`ArrayElement`_  
Pops an array, then an `index (integer)`. Pushes reference-to-element at `index` on array.
* _`ArrayLength`_  
Pops an array. Pushes length of stack (integer) to stack.
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

---

## Data type conversion
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

---

## Misc.
* _`ReturnVal`_  
Pops a value from stack, sets it as the return value of currently executing function. **Does NOT terminate execution**
* _`Terminate`_  
Terminates execution of function. **Must be called at end of function, or it'll segfault**