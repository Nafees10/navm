# NaVM
A barebones VM, intended to be used for scripting applications.  

---

## Getting Started
These instructions will build the demo configuration of NaVM.  

See the documents in `spec/` to know about NaVM syntax and more.  
And `source/app.d` for demo usage.

### Prerequisites
You need to have these present on your machine to build NaVM:

1. dub
2. dlang compiler (tested with `dmd` and `gdc`)
3. `utils` package (dub will fetch it)

### Building
Run:
```bash
dub fetch navm
dub build navm -b=release -c=demo
```
Following this, you will have the demo NaVM binary (named `demo`) with very basic functionality.  

You can now run NaVM bytecode using:  
```bash
./demo path/to/bytecodefile
```

---

## License
NaVM is licensed under the MIT License - see [LICENSE](LICENSE) for details