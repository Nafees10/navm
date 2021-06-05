# Binary Bytecode
This document describes how `NaBytecodeBinary` class stores bytecode in binary format.

The binary file contains these sections of bytecode in the this order:

1. magic number
2. version bytes
3. magic number postfix
4. metadata
5. instruction codes
6. instruction arguments
7. labels

## Magic Number & Version & Magic Number Postfix
This part is always 17 bytes.  

The first 7 bytes are to be:
```
NAVMBC-

OR

4E 41 56 4D 42 43 2D
```
These are followed by 2 bytes, which are used to identify version information.  
8 bytes after these bytes are ignored, these are the magic number postfix.

### Version Identifying Bytes

|	Bytes (Hexadecimal)	|	First NaVM Version	|
| --------------------- | --------------------- |
| 		`00  01`		| 		v1.2			|

Byte combinations not present in table above are reserved for future versions.

## Metadata
An 8 byte (64 bit) unsigned integer used to store number of bytes. Then that number of bytes follows it, storing the metadata.

## Instruction Codes
An 8 byte (64 bit) unsigned integer stores the number of bytes used for storing instruction codes.  
Each instruction code is a `ushort`, so 2 bytes are used for 1 instruction code.

## Instruction Arguments
An 8 byte (64 bit) unsigned integer stores the number of arguments. This is followed by the arguments.  

Arguments are stored as:  
1 byte for `NaInstArgType`, then 8 byte unsigned integer for number of bytes in argument, followed by the bytes for argument.

## Labels
An 8 byte (64 bit) unsigned integer stores the **number of labels** (not bytes). This is followed by the labels.  
A label is stored as:  

1. CodeIndex - fixed length, 8 bytes
2. ArgIndex - fixed length, 8 bytes
3. Name - variable length (`char` array).

---

Any excess bytes at end of last section are ignored

**All data is stored in little endian encoding**