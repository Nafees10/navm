module navm.binary;

import navm.common,
			 navm.meta;

import std.conv : to;
import std.bitmanip;

/// Writes ByteCode to a binary stream
///
/// Returns: binary date in a ubyte[]
public ubyte[] toBin(
		ref Code code,
		ubyte[8] magicPostfix = 0,
		ubyte[] metadata = null){
	// figure out expected length
	size_t expectedSize = binStreamExpectedSize(
			metadata.length, code.labels.length, code.code.length);
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
	stream[seek .. seek + 8] = code.end.nativeToLittleEndian;
	seek += 8;
	stream[seek .. seek + code.code.length] = cast(ubyte[])code.code;
	seek += code.code.length;

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
	if (stream.length < binStreamExpectedSize)
		throw new Exception("Stream size if less than minimum possible size");
	if (stream[0 .. 7] != "NAVMBC-")
		throw new Exception("Invalid header in stream");
	if (stream[7 .. 9] != NAVMBC_VERSION.nativeToLittleEndian)
		throw new Exception("Stream is of different ByteCode version.\n" ~
				"\tStream: " ~ stream[7 .. 9].littleEndianToNative!ushort.to!string ~
				"\tSupported: " ~ NAVMBC_VERSION);
	magicPostfix = stream[9 .. 17];
	size_t len = stream[17 .. 25].littleEndianToNative!size_t;
	if (binStreamExpectedSize(len) > stream.length)
		throw new Exception("Invalid stream length");
	metadata = stream[25 .. 25 + len];
	size_t seek = 25 + len;

	Code code;
	ubyte[8] buf8;
	// labels
	buf8 = stream[seek .. seek + 8];
	len = buf8.littleEndianToNative!size_t;
	if (binStreamExpectedSize(metadata.length, len) > stream.length)
		throw new Exception("Invalid stream length");
	seek += 8;
	code.labels.length = len;
	code.labelNames.length = len;
	foreach (i, ref label; code.labels){
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
	code.end = buf8.littleEndianToNative!size_t;
	if (binStreamExpectedSize(metadata.length, code.labels.length, code.end)
			> stream.length)
		throw new Exception("Invalid stream length");
	code.code = stream[seek .. $].dup;
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
private size_t binStreamExpectedSize(
		size_t metadataLen = 0,
		size_t labelsCount = 0,
		size_t dataLen = 0){
	return 17 + 8 + metadataLen +
		8 + ((8 + 8) * labelsCount) +
		8 + dataLen;
}
