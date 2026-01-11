module navm.binary;

import navm.common,
			 navm.meta;

import std.conv : to;
import std.bitmanip;

/// Writes ByteCode to a binary stream
///
/// Returns: binary date in a ubyte[]
public ubyte[] toBin(I...)(
		ref Code code,
		ubyte[8] magicPostfix = 0,
		ubyte[] metadata = null){
	// figure out expected length
	size_t expectedSize = binStreamExpectedSize(metadata.length, code);
	// count label names sizes, add those
	foreach (name; code.labelNames)
		expectedSize += name.length;
	ubyte[] stream = new ubyte[expectedSize];

	// header
	stream[0 .. 7] = cast(ubyte[])"NAVMBC-";
	stream[7 .. 9] = NAVMBC_VERSION.nativeToLittleEndian;
	stream[9 .. 17] = magicPostfix;

	// metadata
	stream[17 .. 25] = metadata.length.nativeToLittleEndian;
	stream[25 .. 25 + metadata.length] = metadata;
	size_t seek = 25 + metadata.length;

	// labels
	stream[seek .. seek + 8] = code.labels.length.nativeToLittleEndian;
	seek += 8;
	foreach (i, name; code.labelNames){
		stream[seek .. seek + 8] = code.labels[i].nativeToLittleEndian;
		seek += 8;
		stream[seek .. seek + 8] = name.length.nativeToLittleEndian;
		seek += 8;
		stream[seek .. seek + name.length] = cast(ubyte[])cast(char[])name;
		seek += name.length;
	}

	// instructions data
	stream[seek .. seek + 8] = code.code.length.nativeToLittleEndian;
	seek += 8;
	for (size_t i = 0; i < code.code.length;){
		immutable ushort inst = code.code[i .. $].as!ushort;
		i += ushort.sizeof;
		stream[seek .. seek + 2] = inst.nativeToLittleEndian;
		switcher: switch (inst){
			foreach (ind, Inst; T){
				case ind:
					{
						InstArgs!Inst p;
						static foreach (i, Arg; InstArgs!Inst){
							static if (is (Arg == string)){
								size_t arg = *(cast(size_t*)(code.code.ptr + i));
								i += size_t.sizeof;
								stream[seek .. seek + 8] = arg.nativeToLittleEndian;
								seek += size_t.sizeof;
							} else if (isIntegral!Arg || isFloatingPoint!Arg){
								Arg arg = *(cast(Arg*)(code.code.ptr + i));
								i += Arg.sizeof;
								stream[seek .. seek + 8] = arg.nativeToLittleEndian;
								seek += Arg.sizeof;
							} else if (Arg.sizeof == 1){
								stream[seek ++] = code.code[i ++];
							} else {
								static assert (false, "unsupported instruction arg type");
							}
						}
					}
					break switcher;
			}
			default:
				break;
		}
	}

	/// resources data
	for (size_t i = 0; i < code.data.length; ){
		size_t size = *(cast(size_t*)(code.data.ptr + i));
		stream[seek .. seek + 8] = size.nativeToLittleEndian;
		seek += 8;
		i += 8;
		stream[seek .. seek + size] = code.data[i .. i + size];
		i += size;
	}

	return stream;
}

///
unittest{
	Code code;/// empty code
	ubyte[] bin = code.toBin([1, 2, 3, 4, 5, 6, 7, 8], [8, 9, 10]);
	assert(bin.length == 17 + 8 + 3 + 8 + 8);
	assert(bin[0 .. 7] == "NAVMBC-"); // magic bytes
	assert(bin[7 .. 9] == [4, 0]); // version
	assert(bin[9 .. 17] == [1, 2, 3, 4, 5, 6, 7, 8]); // magic postfix
	assert(bin[17 .. 25] == [3, 0, 0, 0, 0, 0, 0, 0]); // length of metadata
	assert(bin[25 .. 28] == [8, 9, 10]); // metadata
}

/// Reads ByteCode from a byte stream in ubyte[]
/// Throws: Exception in case of error
/// Returns: ByteCode
public Code fromBin(ubyte[] stream, ref ubyte[8] magicPostfix,
		ref ubyte[] metadata){
	if (stream.length < binStreamExpectedSize(0, Code()))
		throw new Exception("Stream size if less than minimum possible size");
	if (stream[0 .. 7] != "NAVMBC-")
		throw new Exception("Invalid header in stream");
	if (stream[7 .. 9] != NAVMBC_VERSION.nativeToLittleEndian)
		throw new Exception("Stream is of different ByteCode version.\n" ~
				"\tStream: " ~ stream[7 .. 9].littleEndianToNative!ushort.to!string ~
				"\tSupported: " ~ NAVMBC_VERSION);
	magicPostfix = stream[9 .. 17];
	size_t len = stream[17 .. 25].littleEndianToNative!size_t;
	if (25 + len > stream.length)
		throw new Exception("Invalid stream length");
	metadata = stream[25 .. 25 + len];
	size_t seek = 25 + len;

	Code code;
	ubyte[8] buf8;
	// labels
	if (seek + 8 > stream.length)
		throw new Exception("Invalid stream length");
	buf8 = stream[seek .. seek + 8];
	len = buf8.littleEndianToNative!size_t;
	seek += 8;
	code.labels.length = len;
	code.labelNames.length = len;
	foreach (i, ref label; code.labels){
		if (seek + 8 > stream.length)
			throw new Exception("Invalid stream length");
		buf8 = stream[seek .. seek + 8];
		seek += 8;
		label = buf8.littleEndianToNative!size_t;
		buf8 = stream[seek .. seek + 8];
		seek += 8;
		len = buf8.littleEndianToNative!size_t;
		if (seek + len > stream.length)
			throw new Exception("Invalid stream length");
		code.labelNames[i] = cast(immutable char[])stream[seek .. seek + len].dup;
		seek += len;
	}

	// data
	buf8 = stream[seek .. seek + 8];
	seek += 8;
	code.code.length = buf8.littleEndianToNative!size_t;
	if (binStreamExpectedSize(metadata.length, code) > stream.length)
		throw new Exception("Invalid stream length");
	code.code[] = stream[seek .. code.code.length];
	return code;
}

///
unittest{
	import std.functional, std.range;
	Code code;
	ubyte[] data = iota(cast(ubyte)0, ubyte.max).cycle.take(0).array;
	code.code = data.dup;
	code.labelNames = ["data", "start", "loop", "end"];
	code.labels = [
		0,
		2,
		1025,
		1300,
	];

	ubyte[] bin = code.toBin([1, 2, 3, 4, 5, 6, 7, 8], [1, 2, 3]).dup;
	ubyte[8] postfix;
	ubyte[] metadata;
	Code decoded = bin.fromBin(postfix, metadata);
	assert(postfix == [1, 2, 3, 4, 5, 6, 7, 8]);
	assert(metadata == [1, 2, 3]);
	assert(decoded.labels.length == 4);
	assert(decoded.labels == [0, 2, 1025, 1300]);
	assert(decoded.labelNames[0] == "data");
	assert(decoded.labelNames[1] == "start");
	assert(decoded.labelNames[2] == "loop");
	assert(decoded.labelNames[3] == "end");
	assert(decoded.code == data, decoded.code.to!string);
}

/// Returns: Expected stream size
private size_t binStreamExpectedSize(size_t metadataLen = 0, Code code){
	return 17 + 8 + metadataLen +
		8 + ((8 + 8) * code.labels.length) +
		8 + code.code.length +
		8 + code.data.length;
}
