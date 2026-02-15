module navm.binary;

import navm.common,
			 navm.error,
			 navm.meta;

private void assertLittleEndian() pure {
	version (LittleEndian){} else {
		assert (false,
				"binary serialization only supported on little endian CPUs");
	}
}

/// Writes ByteCode to a binary stream
///
/// Returns: binary date in a ubyte[]
public ubyte[] toBin(ref Code code, ubyte[8] magicPostfix = 0,
		ubyte[] metadata = null){
	assertLittleEndian;
	size_t expectedSize = binStreamExpectedSize(
			metadata.length, code.labels.length, code.code.length, code.data.length);
	// count label names sizes, add those
	foreach (name; code.labelNames)
		expectedSize += name.length;
	void[] stream = allocate!void(expectedSize);

	// header
	stream[0 .. 7] = cast(ubyte[])"NAVMBC-";
	stream[7 .. 9] = NAVMBC_VERSION.asBytes;
	stream[9 .. 17] = magicPostfix;

	// metadata
	stream[17 .. 25] = metadata.length.asBytes;
	stream[25 .. 25 + metadata.length] = metadata;
	size_t seek = 25 + metadata.length;

	// labels
	stream[seek .. seek + 8] = code.labels.length.asBytes;
	seek += 8;
	foreach (i, name; code.labelNames){
		stream[seek .. seek + 8] = code.labels[i].asBytes;
		seek += 8;
		stream[seek .. seek + 8] = name.length.asBytes;
		seek += 8;
		stream[seek .. seek + name.length] = cast(ubyte[])cast(char[])name;
		seek += name.length;
	}

	// instructions
	stream[seek .. seek + 8] = code.code.length.asBytes;
	seek += 8;
	stream[seek .. seek + code.code.length] = code.code;
	seek += code.code.length;

	// data
	stream[seek .. seek + 8] = code.data.length.asBytes;
	seek += 8;
	stream[seek .. seek + code.data.length] = code.data;

	return cast(ubyte[])stream;
}

///
unittest{
	Code code;/// empty code
	ubyte[] bin = code.toBin([1, 2, 3, 4, 5, 6, 7, 8], [8, 9, 10]);
	assert(bin.length == 17 + 8 + 3 + 8 + 8 + 8);
	assert(bin[0 .. 7] == "NAVMBC-"); // magic bytes
	assert(bin[7 .. 9] == [4, 0]); // version
	assert(bin[9 .. 17] == [1, 2, 3, 4, 5, 6, 7, 8]); // magic postfix
	assert(bin[17 .. 25] == [3, 0, 0, 0, 0, 0, 0, 0]); // length of metadata
	assert(bin[25 .. 28] == [8, 9, 10]); // metadata
}

/// Reads ByteCode from a byte stream in ubyte[]
/// Returns: Code or Err
/// the created Code instance will refer to memory in `stream`
public ErrVal!Code fromBin(
		ubyte[] stream,
		ref ubyte[8] magicPostfix,
		ref ubyte[] metadata){
	assertLittleEndian;
	if (stream.length < binStreamExpectedSize)
		return ErrVal!Code(Err.Type.StreamSizeInvalid.Err);
	if (stream[0 .. 7] != "NAVMBC-")
		return ErrVal!Code(Err.Type.StreamHeaderInvalid.Err);
	if (stream[7 .. 9].as!ushort != NAVMBC_VERSION)
		return ErrVal!Code(Err.Type.StreamVersionInvalid.Err);
	magicPostfix = stream[9 .. 17];
	size_t len = stream[17 .. 25].as!size_t;
	if (25 + len > stream.length)
		return ErrVal!Code(Err.Type.StreamSizeInvalid.Err);
	metadata = stream[25 .. 25 + len];
	size_t seek = 25 + len;

	Code code;
	ubyte[8] buf8;
	// labels
	if (seek + 8 > stream.length)
		return ErrVal!Code(Err.Type.StreamSizeInvalid.Err);
	buf8 = stream[seek .. seek + 8];
	len = buf8.as!size_t;
	seek += 8;
	code.labels.length = len;
	code.labelNames.length = len;
	foreach (i, ref label; code.labels){
		if (seek + 8 > stream.length)
			return ErrVal!Code(Err.Type.StreamSizeInvalid.Err);
		buf8 = stream[seek .. seek + 8];
		seek += 8;
		label = buf8.as!size_t;
		buf8 = stream[seek .. seek + 8];
		seek += 8;
		len = buf8.as!size_t;
		if (seek + len > stream.length)
			return ErrVal!Code(Err.Type.StreamSizeInvalid.Err);
		code.labelNames[i] = cast(immutable char[])stream[seek .. seek + len];
		seek += len;
	}

	// instructions
	len = stream[seek .. seek + 8].as!size_t;
	seek += 8;
	if (binStreamExpectedSize(
				metadata.length,
				code.labels.length,
				code.code.length) > stream.length)
		return ErrVal!Code(Err.Type.StreamSizeInvalid.Err);
	code.code = stream[seek .. seek + len];
	seek += len;

	// data
	len = stream[seek .. seek + 8].as!size_t;
	seek += 8;
	if (binStreamExpectedSize(
				metadata.length,
				code.labels.length,
				code.code.length,
				len) > stream.length)
		return ErrVal!Code(Err.Type.StreamSizeInvalid.Err);
	code.data = stream[seek .. seek + len];
	return code.ErrVal!Code;
}

///
unittest{
	import std.functional, std.range;
	import std.conv : to;
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

	ubyte[] bin = code.toBin([1, 2, 3, 4, 5, 6, 7, 8], [1, 2, 3]);
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
		size_t instLen = 0,
		size_t dataLen = 0){
	return 17 + 8 + metadataLen +
		8 + ((8 + 8) * labelsCount) +
		8 + instLen +
		8 + dataLen;
}
