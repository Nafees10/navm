# NaVM Instructions

Here's a list of instructions that NaVM has out of the box. You can easily add more (Add name, argument count, and other info to `source/navm/bytecodedefs.d` and implement those instructions in `source/navm/navm.d`

## Calling functions:

* _`Call [function id - uinteger]`_  
Pops `n (uinteger)`, then pops `n` number of elements as function arguments. Calls a function with the id `function id`. Pushes the return value to stack, if no meaningful data is returned by functions, it pushes a `NaData()`.

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
Pops 2 values from stack, pushes `true (bool)` to stack if both have same value, else, pushes `false (bool)`.
* _`IsSameArray`_  
Pops 2 arrays from stack (arrays, not referece to array). Pushes `true (bool)` to stack if both are same (length, and elements), else, pushes `false (bool)`. **Will only work on 1 dimensional arrays.**
* _`IsSameArrayRef`_  
Pops 2 references to arrays from stack. Pushes `true (bool)` to stack if both are same (length, and elements), else, pushes `false (bool)`. **Will only work on 1 dimensional arrays.**
* _`IsGreaterInt`_  
Pops `A (integer)`, then `B (integer)`. Pushes `true (bool)` if `A > B`, else, pushes `false (bool)`
* _`IsGreaterSameInt`_  
Pops `A (integer)`, then `B (integer)`. Pushes `true (bool)` if `A >= B`, else, pushes `false (bool)`
* _`IsGreaterDouble`_  
Pops `A (double)`, then `B (double)`. Pushes `true (bool)` if `A > B`, else, pushes `false (bool)`
* _`IsGreaterSameDouble`_  
Pops `A (double)`, then `B (double)`. Pushes `true (bool)` if `A >= B`, else, pushes `false (bool)`
* _`NotBool`_  
Pops `A (bool)`. Pushes `!A`
* _`AndBool`_  
Pops `A (bool)` and then `B (bool)`. Pushes `A && B`
* _`OrBool`_  
Pops `A (bool)` and then `B (bool)`. Pushes `A || B`

---

## Stack
* _`Push [arg0 - any data type]`_  
Pushes `arg0` to stack
* _`PushFrom [index - uinteger]`_  
Reads value at `stack.peek - index` on stack, pushes it, without removing original.
* _`PushRefFrom [index - uinteger]`_  
Pushes reference to value at `stack.peek - index` on stack, without removing original.
* _`WriteTo [index - uinteger]`_  
Pops a value from stack, writes it to `stack.peek - index` on stack.
* _`WriteToRef`_  
Pops a reference, then pops a value. Writes value to reference.
* _`Deref`_  
Pops a reference from stack. Pushes the value being referenced
* _`Pop`_  
Pops 1 value from stack
* _`PopN [n - uinteger]`_  
Pops n number of values from stack

---

## Jumps
* _`Jump [jump positionIdentifier]`_  
Jump execution to instruction at `jump position`. **Be careful using this, make sure you have used `Pop` to clear stack of unneeded elements**
* _`JumpIf [jump positionIdentifier]`_  
Pops `bool` from stack. If it is `true`, jumps execution to instruction at `jump position`. **Be careful using this, make sure you have used `Pop` to clear stack of unneeded elements**

---

## Arrays
* _`MakeArray [n - uinteger>0]`_  
Pops `n` number of elements from stack, puts them in an array (in the order they were added to stack). Pushes array to stack.
* _`ArrayRefElement`_  
Pops a reference to array, then an `index (uinteger)`. Pushes reference-to-element at `index` on array.
* _`ArrayElement`_  
Pops an array, then an `index (uinteger)`. Pushes reference-to-element at `index` on array.
* _`ArrayLength`_  
Pops an array. Pushes length of array (`uinteger`) to stack.
* _`ArrayLengthSet`_  
Pops a reference to array, then `length (uinteger)`. Sets length of array to `length`
* _`Concatenate`_  
Pops an array `a1` _(not reference)_, then pops another array `a2`. Pushes new array `a1 ~ a2`.
* _`AppendElement`_  
Pops a reference to array, then an element. Appends element at end of array.
* _`AppendArrayRef`_  
Pops reference to array `r1`, pops another `r2`. Then does `*r1 = *r1 ~ *r2`
* _`AppendArray`_  
Pops reference to array `r1`, then pops an array _(not reference)_. Then does `*r1 = *r1 ~ r2`
* _`copyArray`_  
Pops an array, makes a copy of it, pushes the copy to stack. Any changes made to copy won't reflect on original.  
**Will only work on 1 dimensional arrays.**
* _`copyArrayRef`_  
Pops a ref-to-array, makes a copy of array, pushes to stack. Any changes made to copy won't reflect on original.  
**Will only work on 1 dimensional arrays.**

---

## Data type conversion
* _`IntToDouble`_  
Pops an integer from stack. Pushes a double with same value.
* _`IntToString`_  
Pops an integer from stack. Pushes a string representation of it.
* _`BoolToString`_  
Pops a bool from stack. Pushes `"true"` or `"false"` (string) depending on bool.
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
Pops a value from stack, sets it as the return value.**Does NOT terminate execution**
* _`Terminate`_  
Terminates execution.

--

## D equivalent of data types in NaVM
* `uinteger` is a `ulong` or `uint` depending on whether it is compiled for 64bit or 32bit. or you could use `uinteger` from `misc.d` from package `utils`.
* `integer` is a `long` or `int` depending on whether it is compiled for 64bit or 32bit.  or you could use `integer` from `misc.d` from package `utils`.
* `string` is a `dstring`
* `char` is a `dchar`
* `bool` is the same as a D `bool`
* arrays are `NaData[]` (stored in `NaData.arrayVal`).