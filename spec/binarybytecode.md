# Binary Bytecode
This document describes how `NaBytecodeBinary` class stores bytecode in binary format.

The binary file contains these sections of bytecode in the this order:

1. signature bytes
2. metadata
3. instruction codes
4. instruction arguments
5. labels

## Storing Variable Length Data
if data is not fixed length, it will be stored as:  
First 4 bytes to store length (unsigned int), followed by the data.  
  
This is used when storing data like strings, metadata.  
Sections, except for Signature Bytes, are all stored this way.

## Signature Bytes
This part is always 11 bytes.  

The first 7 bytes are to be:
```
NAVMBC-

OR

4E 41 56 4D 42 43 2D
```
4 bytes after these bytes are ignored.

## Metadata
This can be used to store any data along with bytecode, or can be left empty.

## Instruction Codes
Each instruction code is a `ushort`, so 2 bytes are used for 1 instruction code.

## Instruction Arguments
Each argument is stored as:  
1 byte for NaInstArgType + rest of bytes for argument itself.  

if an argument is fixed length or not is determined by its type:  

* Literal - treated as an int, fixed length, 8 bytes
* LiteralInteger - fixed length, 8 bytes
* LiteralUInteger - fixed length, 8 bytes
* Address - fixed length, 8 bytes
* LiteralBoolean - fixed length, 1 byte
* LiteralString - variable length
* Label - variable length (label name is stored)

## Labels
A label is stored as:  

1. CodeIndex - fixed length, 8 bytes
2. ArgIndex - fixed length, 8 bytes
3. Name - variable length

---

Any excess bytes at end of last section are ignored