module navm.bytecode;

import utils.misc : readHexadecimal, readBinary, isNum;

import navm.common;

import std.conv,
			 std.uni,
			 std.meta,
			 std.array,
			 std.string,
			 std.traits,
			 std.algorithm;

/// Position Independent Code
/// (label names, labels, instructions, data, & indexes of relative address)
public struct PICode{
	Code _code;
	alias _code this;
	size_t[] rel; /// indexes of relative addresses in data, relative to data.ptr
}

/// Byte Code (ready for execution)
public struct Code{
	string[] labelNames; /// label index against each labelName
	size_t[2][] labels; /// [codeIndex, dataIndex] for each labal
	ushort[] instructions; /// instruction codes
	ubyte[] data; /// instruction data
}

/// ByteCode version
public enum ushort NAVMBC_VERSION = 0x02;

/// Parse string[] lines into bytecode
/// Template parameters are functions for instructions
/// Throws: Exception on invalid bytecode
/// Returns: ByteCode
public PICode parseByteCode(T...)(string[] lines) if (
		allSatisfy!(isCallable, T)){
	PICode ret;
	size_t[] absPos = [0]; /// index of arguments in data array
	size_t[3][] cdataAddr; /// [index in data, index in cdata, length]
	ubyte[] cdata;
	foreach (lineNo, line; lines){
		string[] splits = line.separateWhitespace.filter!(a => a.length > 0).array;
		if (splits.length == 0)
			continue;
		if (splits[0].length && splits[0][$ - 1] == ':'){
			string name = splits[0][0 .. $ - 1];
			if (ret.labelNames.canFind(name))
				throw new Exception("line " ~ (lineNo + 1).to!string ~
						" label name redeclared");
			ret.labelNames ~= name;
			ret.labels ~= [
				ret.instructions.length,
				ret.data.length
			];
			splits = splits[1 .. $];
			if (splits.length == 0)
				continue;
		}

		caser: switch (splits[0]){
			static foreach (ind, Inst; T){
				case __traits(identifier, Inst):
					splits = splits[1 .. $];
					if (splits.length!= InstArity!Inst)
						throw new Exception("line " ~ (lineNo + 1).to!string ~ ": " ~
								__traits(identifier, Inst) ~
								" instruction expects " ~ InstArity!Inst.to!string ~
								" arguments, got " ~ (splits.length).to!string);
					ret.instructions ~= ind;
					readArgs!Inst(ret, splits, cdataAddr, cdata, absPos);
					break caser;
			}
			default:
				throw new Exception("line " ~ (lineNo + 1).to!string ~
						": Instruction expected, got `" ~ splits[0] ~ "`");
		}
	}

	immutable size_t dataLen = ret.data.length;
	ret.data ~= cdata;
	foreach (ind; cdataAddr){
		ret.data[ind[0] .. ind[0] + string.sizeof] =
			(ret.data[dataLen + ind[1] .. dataLen + ind[1] + ind[2]]).asBytes;
	}

	size_t dc;
	foreach (lineNo, line; lines){
		string[] splits = line.separateWhitespace.filter!(a => a.length > 0).array;
		if (splits.length == 0)
			continue;
		if (splits[0].length && splits[0][$ - 1] == ':')
			splits = splits[1 .. $];
		if (splits.length == 0)
			continue;
		switcharoo: switch (splits[0]){
			static foreach (ind, Inst; T){
				case __traits(identifier, Inst):
					splits = splits[1 .. $];
					static foreach (argInd, Arg; InstArgs!Inst){{
						immutable string arg = splits[argInd];
						static if (isIntegral!Arg){
							if (arg.length && arg[0] == '@'){
								size_t addr = arg[1 .. $].resolveAddress(ret, absPos);
								ret.data[absPos[dc] .. absPos[dc] + Arg.sizeof] =
									(cast(Arg)addr).asBytes;
							}
						}}
						dc ++;
					}
					break switcharoo;
			}
			default:
				throw new Exception("line " ~ (lineNo + 1).to!string ~
						": Instruction expected, got `" ~ splits[0] ~ "`");
		}
	}
	return ret;
}

private void readArgs(alias Inst)(
		ref PICode ret,
		string[] args,
		ref size_t[3][] cdataAddr,
		ref ubyte[] cdata,
		ref size_t[] absPos){
	static foreach (i, Arg; InstArgs!Inst){
		static if (is (Arg == string)){
			if (args[i].length && args[i][0] == '"'){
				ubyte[] data = parseData!Arg(args[i]);
				if (data == null){
					throw new Exception("line " ~ (i + 1).to!string ~
							": Invalid data `" ~ args[i] ~ "` for " ~ Arg.stringof);
				}
				ret.rel ~= ret.data.length;
				cdataAddr ~= [ret.data.length, cdata.length, data.length];
				ret.data ~= size_t.max.asBytes;
				ret.data ~= data.length.asBytes;
				// add any extra bytes that string might have
				static if (string.sizeof > size_t.sizeof * 2)
					ret.data.length += string.sizeof - (size_t.size_t * 2);
				absPos ~= absPos[$ - 1] + size_t.sizeof + size_t.sizeof;
				cdata ~= data;
			} else {
				throw new Exception("line " ~ (i + 1).to!string ~
						": Expected string, got `" ~ args[i] ~ "`");
			}

		} else static if (isIntegral!Arg){
			if (args[i].length && args[i][0] == '@'){
				ret.data.length += Arg.sizeof;
				absPos ~= absPos[$ - 1] + Arg.sizeof;
			} else {
				ubyte[] data = parseData!Arg(args[i]);
				if (data == null)
					throw new Exception("line " ~ (i + 1).to!string ~
							": Invalid data `" ~ args[i] ~ "` for " ~ Arg.stringof);
				ret.data ~= data;
				absPos ~= absPos[$ - 1] + data.length;
			}

		} else {
			ubyte[] data = parseData!Arg(args[i]);
			if (data == null)
				throw new Exception("line " ~ (i + 1).to!string ~
						": Invalid data `" ~ args[i] ~ "` for " ~ Arg.stringof);
			ret.data ~= data;
			absPos ~= absPos[$ - 1] + data.length;
		}
	}
}

private size_t resolveAddress(string arg, ref PICode code, size_t[] absPos){
	ptrdiff_t plusInd = arg.indexOf('+');
	if (plusInd != -1){
		string label = arg[0 .. plusInd];
		size_t offset = size_t.max;
		try {
			offset = arg[plusInd + 1 .. $].to!size_t;
		} catch (Exception){}
		if (offset == size_t.max || (
					label.length && !code.labelNames.canFind(label)))
			throw new Exception("Invalid address `" ~ arg ~ "`");
		size_t pos = offset +
			(label.length ? code.labels[code.labelNames.countUntil(label)][1] : 0);
		if (pos > absPos.length)
			throw new Exception("Invalid offset `" ~ arg ~ "`");
		return absPos[pos];
	}
	// its a label address
	if (!code.labelNames.canFind(arg))
		throw new Exception("Invalid address `" ~ arg ~ "`");
	return code.labelNames.countUntil(arg);
}

///
unittest{
	void push(size_t){}
	void push2(size_t, size_t){}
	void pop(){}
	void add(){}
	void print(){}
	alias parse = parseByteCode!(push, push2, pop, add, print);
	string[] source = [
		"data: push 50",
		"start: push 50",
		"push @data+2",
		"push2 1 2",
		"add",
		"print"
	];
	PICode code = parse(source);
	assert(code.labels.length == 2);
	assert(code.labelNames.canFind("data"));
	assert(code.labelNames.canFind("start"));
	assert(code.labels[0] == [0, 0]);
	assert(code.labels[1] == [1, 8]);
	assert(code.instructions == [0, 0, 0, 1, 3, 4]);
	// tests for code.data are missing
}

/// Returns: Expected stream size
private size_t binStreamExpectedSize(
		size_t metadataLen = 0,
		size_t instructionsCount = 0,
		size_t dataLen = 0,
		size_t labelsCount = 0){
	return 17 + 8 + metadataLen +
		8 + (instructionsCount * 2) +
		8 + dataLen +
		8 + ((8 * 3) * labelsCount);
}

/// Writes ByteCode to a binary stream
///
/// Returns: binary date in a ubyte[]
public ubyte[] toBin(ref PICode code, ubyte[7] magicPostfix = 0,
		ubyte[] metadata = null){
	// figure out expected length
	size_t expectedSize = binStreamExpectedSize(
			metadata.length, code.instructions.length, code.data.length,
			code.labels.length);
	// count label names sizes, add those
	foreach (name; code.labelNames)
		expectedSize += name.length;
	ubyte[] stream = new ubyte[expectedSize];

	// header
	stream[0 .. 7] = cast(ubyte[])cast(char[])"NAVMBC-";
	stream[7 .. 9] = ByteUnion!ushort(NAVMBC_VERSION).bytes;
	stream[9 .. 16] = magicPostfix;

	// metadata
	stream[16 .. 24] = ByteUnion!(size_t, 8)(metadata.length).bytes;
	stream[24 .. 24 + metadata.length] = metadata;
	size_t seek = 24 + metadata.length;

	// instructions
	stream[seek .. seek + 8] =
		ByteUnion!(size_t, 8)(code.instructions.length * 2).bytes;
	seek += 8;
	foreach (inst; code.instructions){
		stream[seek .. seek + 2] = ByteUnion!(ushort, 2)(inst).bytes;
		seek += 2;
	}

	// data
	stream[seek .. seek + 8] = ByteUnion!(size_t, 8)(code.data.length).bytes;
	seek += 8;
	stream[seek .. seek + code.data.length] = code.data;
	seek += code.data.length;

	// labels
	stream[seek .. seek + 8] = ByteUnion!(size_t, 8)(code.labels.length).bytes;
	seek += 8;
	foreach (i, name; code.labelNames){
		stream[seek .. seek + 8] = ByteUnion!(size_t, 8)(code.labels[i][0]).bytes;
		seek += 8;
		stream[seek .. seek + 8] = ByteUnion!(size_t, 8)(code.labels[i][1]).bytes;
		seek += 8;
		stream[seek .. seek + 8] = ByteUnion!(size_t, 8)(name.length).bytes;
		seek += 8;
		stream[seek .. seek + name.length] = cast(ubyte[])cast(char[])name;
		seek += name.length;
	}
	return stream;
}

///
unittest{
	PICode code;/// empty code
	ubyte[] bin = code.toBin([1, 2, 3, 4, 5, 6, 7], [8, 9, 10]);
	assert(bin.length == 17 + 8 + 3 + 8 + 8 + 8);
	assert(bin[0 .. 7] == "NAVMBC-"); // magic bytes
	assert(bin[7 .. 9] == [2, 0]); // version
	assert(bin[9 .. 16] == [1, 2, 3, 4, 5, 6, 7]); // magic postfix
	assert(bin[16 .. 24] == [3, 0, 0, 0, 0, 0, 0, 0]); // length of metadata
	assert(bin[24 .. 27] == [8, 9, 10]); // metadata
}

/// Reads ByteCode from a byte stream in ubyte[]
/// Throws: Exception in case of error
/// Returns: ByteCode
public PICode fromBin(ubyte[] stream, ref ubyte[7] magicPostfix,
		ref ubyte[] metadata){
	if (stream.length < binStreamExpectedSize)
		throw new Exception("Stream size if less than minimum possible size");
	if (stream[0 .. 7] != "NAVMBC-")
		throw new Exception("Invalid header in stream");
	if (stream[7 .. 9] != ByteUnion!(ushort, 2)(NAVMBC_VERSION).bytes)
		throw new Exception("Stream is of different ByteCode version.\n" ~
				"\tStream: " ~ ByteUnion!ushort(stream[7 .. 9]).data.to!string ~
				"\tSupported: " ~ NAVMBC_VERSION);
	magicPostfix = stream[9 .. 16];
	size_t len = ByteUnion!(size_t, 8)(stream[16 .. 24]).data;
	if (binStreamExpectedSize(len) > stream.length)
		throw new Exception("Invalid stream length");
	metadata = stream[24 .. 24 + len];
	size_t seek = 24 + len;

	PICode code;
	// instructions
	len = ByteUnion!(size_t, 8)(stream[seek .. seek + 8]).data;
	if (binStreamExpectedSize(metadata.length, len / 2) > stream.length)
		throw new Exception("Invalid stream length");
	seek += 8;
	code.instructions = (cast(ushort*)(stream.ptr + seek))[0 .. len / 2];
	seek += len;

	// data
	len = ByteUnion!(size_t, 8)(stream[seek .. seek + 8]).data;
	if (binStreamExpectedSize(metadata.length, code.instructions.length, len)
			> stream.length)
		throw new Exception("Invalid stream length");
	seek += 8;
	code.data = stream[seek .. seek + len];
	seek += len;

	// labels
	len = ByteUnion!(size_t, 8)(stream[seek .. seek + 8]).data;
	if (binStreamExpectedSize(metadata.length,
				code.instructions.length,
				code.data.length, len) > stream.length)
		throw new Exception("Invalid stream length");
	seek += 8;
	code.labels.length = len;
	code.labelNames.length = len;
	foreach (i, ref label; code.labels){
		label[0] = ByteUnion!(size_t, 8)(stream[seek .. seek + 8]).data;
		seek += 8;
		label[1] = ByteUnion!(size_t, 8)(stream[seek .. seek + 8]).data;
		seek += 8;
		len = ByteUnion!(size_t, 8)(stream[seek .. seek + 8]).data;
		seek += 8;
		if (seek + len > stream.length)
			throw new Exception("Invalid stream length");
		code.labelNames[i] = cast(immutable char[])stream[seek .. seek + len];
		seek += len;
	}
	return code;
}

///
unittest{
	import std.functional, std.range;
	PICode code;
	ushort[] instructions = iota(cast(ushort)1, ushort.max, 50).array;
	ubyte[] data = iota(cast(ubyte)0, ubyte.max).cycle.take(3000).array;
	code.instructions = instructions.dup;
	code.data = data.dup;
	code.labelNames = ["data", "start", "loop", "end"];
	code.labels = [
		[0, 0],
		[2, 8],
		[1025, 2020],
		[1300, 3000]
	];

	ubyte[] bin = code.toBin([1, 2, 3, 4, 5, 6, 7], [1, 2, 3]).dup;
	ubyte[7] postfix;
	ubyte[] metadata;
	PICode decoded = bin.fromBin(postfix, metadata);
	assert(postfix == [1, 2, 3, 4, 5, 6, 7]);
	assert(metadata == [1, 2, 3]);
	assert(decoded.instructions == instructions);
	assert(decoded.data == data);
	assert(decoded.labels.length == 4);
	assert(decoded.labels[0] == [0, 0]);
	assert(decoded.labels[1] == [2, 8], decoded.labels[1].to!string);
	assert(decoded.labels[2] == [1025, 2020]);
	assert(decoded.labels[3] == [1300, 3000]);
	assert(decoded.labelNames[0] == "data");
	assert(decoded.labelNames[1] == "start");
	assert(decoded.labelNames[2] == "loop");
	assert(decoded.labelNames[3] == "end");
}

/// Parses data, asBytes it into ubyte[].
///
/// Returns: resulting ubyte[], or `null` if invalid or address or label
private ubyte[] parseData(T)(string s){
	static if (isIntegral!T){
		// can be just an int
		if (isNum(s, false))
			return s.to!T.asBytes;
		// can be a binary or hex literal
		if (s.length > 2 && s[0] == '0'){
			try{
				if (s[1] == 'b')
					return (cast(T)readBinary(s[2 .. $])).asBytes;
				else if (s[1] == 'x')
					return (cast(T)readHexadecimal(s[2 .. $])).asBytes;
			} catch (Exception){
				return null;
			}
		}
		// or it can be a address
		return null;

	} else static if (isFloatingPoint!T){
		if (isNum(s, true))
			return s.to!T.asBytes;
		return null;
	} else static if (is (T == bool)){
		if (s == "true")
			return true.asBytes;
		if (s == "false")
			return false.asBytes;
		return null;

	} else static if (isSomeChar!T){
		if (s.length < 2 || s[0] != s[$ - 1] || s[0] != '\'')
			return null;
		s = s[1 .. $ - 1].unescape;
		try{
			return s.to!T;
		} catch (Exception){
			return null;
		}

	} else static if (is (T == string)){
		if (s.length < 2 || s[0] != s[$ - 1] || s[0] != '\"')
			return null;
		s = s[1 .. $ - 1].unescape;
		try{
			T str = s.to!T;
			return cast(ubyte[])cast(char[])str;
		} catch (Exception){
			return null;
		}
	} else {
		static assert(false, "Unsupported argument type " ~ T.stringof);
	}
}

///
unittest{
	assert("true".parseData!bool.as!bool == true);
	assert("false".parseData!bool.as!bool == false);
	assert("0x50".parseData!size_t.as!size_t == 0x50);
	assert("0b101010".parseData!size_t.as!size_t == 0b101010);
	assert("12345".parseData!size_t.as!size_t == 1_2345);
	assert("\"bla bla\"".parseData!string.as!string == "bla bla");
	assert("5.5".parseData!double.as!double == "5.5".to!double);
}
