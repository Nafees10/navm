# Binary Bytecode

This document describes how `NaBytecodeBinary` class stores bytecode in binary
format. The version described in this document is the latest, see table below.

The binary file contains these sections of bytecode in the this order:

1. magic number
2. version bytes
3. magic number postfix
4. metadata
5. instruction codes
6. instruction data
7. labels

## Magic Number & Version & Magic Number Postfix

This part is always 17 bytes.

The first 7 bytes are to be:

ASCII:
```
NAVMBC-
```

hexadecimal:
```
4E 41 56 4D 42 43 2D
```
These are followed by 2 bytes, which are used to identify version information.

8 bytes after these bytes are ignored, these are the magic number postfix.

### Version Identifying Bytes

| Version number, ushort|	First NaVM Version		|
| --------------------- | --------------------- |
| 		`0x0001`					| 		v1.2							|
| 		`0x0002`					| 		v2.0							|

Since all integers are stored in little endian, `0x0001` will be stored as:
`01 00`

Byte combinations not present in table above are reserved for future versions.

## Metadata

An 8 byte (64 bit) unsigned integer used to store number of bytes in metadata,
followed by the metadata.

## Instruction Codes

An 8 byte (64 bit) unsigned integer stores the _number of bytes_ used for
storing instruction codes. Each instruction code is a `ushort`, so 2 bytes are
used for 1 instruction code.

## Instruction Data

An 8 byte (64 bit) unsigned integer stores the _number of bytes_ used for
storing instructio data. This is followed by that many number of bytes of data.

## Labels

An 8 byte (64 bit) unsigned integer stores the number of labels. This is
followed by the labels.

A label is stored as:

1. CodeIndex - fixed length, 8 bytes
2. ArgIndex - fixed length, 8 bytes
3. Name - variable length (`char` array).

---

Any excess bytes at end of last section are ignored

**All integers are stored in little endian encoding**
