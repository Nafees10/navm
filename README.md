# NaVM
A VM designed to be fast, intended for use in scripting languages.  
  
_It's sometimes written navm instead of NaVM, both are the same_

---

## Getting Started
These instructions will get you a copy of NaVM with its very basic instuctions, which will serve as a demo.  
Remember, NaVM is not built to be a standalone application, it's meant to be used as a library (originally built
for QScript, but everyone's free to use it).  

See the documents in `spec/` to know about NaVM syntax, built in instructions, and more.  
And `source/app.d` for example on adding new instructions.

### Prerequisites
You need to have these present on your machine to build NaVM:

1. dub
2. dlang compiler (I've only tested with `dmd`)

### Building
Run:
```bash
dub fetch navm
dub build navm -b=release -c=demo
```
Following this, you will have the demo NaVM binary (named `demo`) with very basic functionality.  

You can now run NaVM bytecode using:  
```bash
~/.dub/packages/navm-*/navm/demo path/to/bytecodefile
```

The demo program contains 4 additional instructions:
* `writeInt` - pops 1 integer from stack, and writes it to stdio.
* `writeDouble` - pops 1 double from stack, and writes it to stdio.
* `writeChar` - pops 1 char from stack, and writes it to stdio.
* `writeStr` - pops 1 string from stack, and writes it to stdio.
* `printDebug` - prints how many elements are in stack, and `_stackIndex` to stdio.

---

## License
NaVM is licensed under the MIT License - see [LICENSE](LICENSE) for details