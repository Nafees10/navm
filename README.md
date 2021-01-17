# NaVM
A VM designed to be fast, intended for use in scripting languages.  
  
_It's sometimes written navm instead of NaVM, both are the same_

---

## Getting Started
These instructions will get you a copy of NaVM with its very basic instuctions, which will serve as a demo.  
Remember, NaVM is not built to be a standalone application, it's meant to be used as a library (originally built
for QScript, but everyone's free to use it).  

See `source/app.d` to see how to add new instructions, & execute byte codes.
  
See `spec/syntax.md` and `spec/instructions.md` for NaVM's syntax and a list of instructions you can use.  

See `examples/*` for some example byte codes. These can be run using the demo build.

### Prerequisites
You need to have these present on your machine:

1. dub
2. dlang compiler (`dmd` works)

### Building
Run:
```bash
dub fetch navm
```
to download this package, and then run:
```bash
dub build navm -b=release -c=demo
```
to fetch dependencies and build NaVM.  
Following this, you will have the NaVM binary (named `demo`) with very basic functionality.  

You can now run NaVM bytecode using:  
```bash
~/.dub/packages/navm-*/navm/demo path/to/bytecodefile
```

The demo program contains 4 additional instructions:
* `writeInt` - pops 1 integer from stack, and writes it to stdio.
* `writeDouble` - pops 1 double from stack, and writes it to stdio.
* `writeChar` - pops 1 char from stack, and writes it to stdio.
* `writeStr` - pops 1 string (array of char) from stack, and writes it to stdio.

---

## License
NaVM is licensed under the MIT License - see [LICENSE](LICENSE) for details