# NaVM
A VM designed to be fast, intended for use in scripting languages.  
  
_It's sometimes written navm instead of NaVM, both are the same_

---

## Getting Started
These instructions will get you a copy of NaVM with its very basic instuctions, which will serve as a demo.  
Remember, NaVM is not built to be a standalone application, it's meant to be used as a library (originally built
for QScript, but everyone's free to use it).  

See `source/app.d` to see how to add external functions, and use it in your program.  
  
See `spec/syntax.md` and `spec/instructions.md` for NaVM's syntax and a list of instructions you can use.  

See `examples/*` for some example byte codes. These can be run using the demo build.

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
dub build navm -b=release -c=demo
```
to fetch dependencies and build NaVM.  
Following this, you will have the NaVM binary (named `demo`) with very basic functionality.  

You can now run NaVM bytecode using:  
```
~/.dub/packages/navm-*/navm/demo path/to/bytecodefile
```


This binary also has 5 external functions:

* ID: 0, call using *`ExecuteFunctionExternal 0 n`* where n is number of integers to pop from stack and writeln(int) to terminal
* ID: 1, call using *`ExecuteFunctionExternal 1 n`* where n is number of doubles (floats) to pop from stack and writeln(double) to terminal
* ID: 2, call using *`ExecuteFunctionExternal 2 n`* where n is number of strings to pop from stack and write to terminal
* ID: 4, call using *`ExecuteFunctionExternal 3 0`* reads a line from stdin, pushes it to stack

---

## License
NaVM is licensed under the MIT License - see [LICENSE](LICENSE) for details