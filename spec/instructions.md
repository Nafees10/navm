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
* _`Not`_  
Pops `A (bool)`. Pushes `!A`
* _`And`_  
Pops `A (bool)` and then `B (bool)`. Pushes `A && B`
* _`Or`_  
Pops `A (bool)` and then `B (bool)`. Pushes `A || B`

---

## Stack
* _`Push [arg0 - any data type]`_  
Pushes `arg0` to stack
* _`PushFromAbs [index - integer>=0]`_  
Reads value at `index` on stack, pushes it, without removing original.
* _`PushRefFromAbs [index - integer>=0]`_  
Pushes reference to value at `index` on stack, without removing original.
* _`WriteToAbs [index - integer>=0]`_  
Pops a value from stack, writes it to `index` on stack.
* _`PushFrom [index - integer>=0]`_  
Reads value at `_stackIndex + index` on stack, pushes it, without removing original.
* _`PushRefFrom [index - integer>=0]`_  
Pushes reference to value at `_stackIndex + index` on stack, without removing original.
* _`WriteTo [index - integer>=0]`_  
Pops a value from stack, writes it to `_stackIndex + index` on stack.
* _`Pop`_  
Pops 1 value from stack
* _`PopN [n - integer>=0]`_  
Pops n number of values from stack

---

## References
* _`WriteToRef`_  
Pops a reference, then pops a value. Writes value to reference.
* _`Deref`_  
Pops a reference from stack. Pushes the value being referenced
* _`IncRef`_  
Pops a reference, then an integer (can be negative). Adds integer to reference, pushes reference back.

---

## Jumps
* _`if`_  
Pops `bool` from stack. The next instruction is only executed if the popped value `==true`.
* _`Jump [jump position]`_  
Jump execution to instruction at `jump position`.
* _`JumpFrame [jump position]`_  
Jump execution to `jump position`. Pushes current frame to a separate stack, so `jumpBack` can be used to jump back.
Also changes `_stackIndex` to `_stack.count`.
* _`JumpBack`_  
Jump execution back to last pointer pushed to jump stack, & restores last frame pushed. `terminate`s if jump stack is empty.

---

## Arrays

_NOTE: array reference refers to the reference to the array's first element._

* _`MakeArray`_  
Pops n (`integer >= 0`), creates an array of length `n`. Pushes its reference to stack.
* _`ArrayLength`_  
Pops a reference-to-array. Pushes length of array (`integer>=0`) to stack.
* _`ArrayLengthSet`_  
Pops a reference-to-array, then `length (integer>=0)`. Creates a new array of length, and copies elements from previous array. Pushes reference of new array.

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
* _`StringToBool`_  
Pops a string, pushes `true (bool)` if it is `"true"`, otherwise pushes `false (bool)`.

---

## Misc.
* _`Terminate`_  
Terminates execution.

--

## D equivalent of data types in NaVM
* `integer` is a `long` or `int` depending on whether it is compiled for 64bit or 32bit.  or you could use `integer` from `misc.d` from package `utils`.
* `string` is a `dstring`
* `char` is a `dchar`
* `bool` is the same as a D `bool`
* arrays are `NaData[]` (stored in `NaData.arrayVal`).