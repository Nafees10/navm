# NaVM
A barebones VM, intended to be used for scripting applications.

---

## Getting Started

These instructions will build the demo configuration of NaVM.

See the documents:

* `docs/binarybytecode.md` - Binary ByteCode format
* `syntax.md` - Syntax description
* `tests/*` - Some test bytecodes, to be run using the NaVM demo

### Prerequisites

You need to have these present on your machine to build NaVM:

1. dub
2. dlang compiler (`ldc` usually generates best performing code)
3. git

### Building

```bash
git clone https://github.com/Nafees10/navm.git
cd navm
dub build -b=release -c=demo # --compiler=ldc
```

This will compile the NaVM demo binary named `demo`.

You can now run NaVM bytecode using:

```bash
./demo tests/default [numberOfTimesToRun]
```

Replace `tests/default` with a path to a bytecode file.

---

## Creating a VM

A VM using NaVM is created using simple functions. A very basic VM with only 2
instructions, `printSum int int`, and `print int`, can be created as:

```d
import navm.navm;
void printSum(ptrdiff_t a, ptrdiff_t b){
	writeln(a + b);
}
void print(ptrdiff_t a){
	writeln(a);
}
// load bytecode. bytecodeSource is the bytecode in a string
ByteCode code;
try {
	code = parseByteCode!(printSum, print)(bytecodeSource);
} catch (Exception e){
	// probably an error in the bytecode
}
// execute the code
execute!(printSum, print)(code);
```

### Starting at a label

```d
import std.algorithm : countUntil, canFind;
ByteCode code;
// locate the index of the label
ptrdiff_t index = code.labels.countUntil("labelName");
if (index == -1){
	throw new Exception("labelName does not exist");
}
execute!(..)(code, index);
```

### Jumps

An instruction can cause execution to jump to another place in the bytecode, by
receiving references to the instruction counter `_ic` and data counter `_dc`.

The instruction counter stores index of the next instruction to execute, and
the data counter stores the index in the argument data array for the
corresponding instruction.

The most common use case for jumps would be jumping to some label. A jump to a
label could be implemented as:

```d
void jump(ref ByteCode code, ref size_t _ic, ref size_t _dc, size_t label){
	// code.labels is an array of [instructionIndex, dataIndex] for each label,
	// where index is the label index
	_ic = code.labels[label][0];
	_dc = code.labels[label][1];
}
```

Example usage:

```
start:
	printS "Hello\n"
loop:
	printS "Looping forever\n"
	jump @loop
```

### Shared state

Since the instruction functions have to be functions and not delegates, there
was one way to have shared data between instructions: global variables.

However that would get tricky with multiple execute calls, so an alternative is
to use the `_state` parameter. An overload of `execute` can be passed a ref of
a struct instance, which it will pass on to any instruction that needs it:

```d
struct Stack {
	ptrdiff_t[512] arr;
	size_t top;
}
void push(ref Stack _state, size_t value){
	_state.arr[top ++] = value;
}
void pop(ref Stack _state){
	_state.top --;
}
import std.meta : AliasSeq;
alias InstrucionSet = AliasSeq!(push, pop);
// load
ByteCode code = parseByteCode!InstrucionSet(bytecodeSource);
Stack stack;
// execute
execute!(Stack, InstrucionSet)(code, stack);
```

---

## License
NaVM is licensed under the MIT License - see [LICENSE](LICENSE) for details
