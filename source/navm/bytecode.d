module navm.bytecode;

import utils.misc : readHexadecimal, readBinary, isNum;
import utils.ds : FIFOStack;

import navm.common;

import std.conv,
			 std.uni,
			 std.meta,
			 std.array,
			 std.string,
			 std.traits,
			 std.typecons,
			 std.algorithm;

/// Position Independent Code
/// (label names, labels, instructions, data, & indexes of relative address)
public struct ByteCode{
	string[] labelNames; /// label index against each labelName
	size_t[] labels; /// [codeIndex, dataIndex] for each labal
	ubyte[] code; /// instructions and their data
	size_t end; /// index+1 of last instruction in code
}

/// ByteCode version
public enum ushort NAVMBC_VERSION = 0x02;

public ByteCode parseByteCode(T...)(string[] lines)
		if (allSatisfy!(isCallable, T)){
	ByteCode ret;
	string[][] argsAll;

	// pass 1: split args, and read labels
	foreach (lineNo, line; lines){
		string[] splits = line.separateWhitespace.filter!(a => a.length > 0).array;
		if (splits.length == 0) continue;
		if (splits[0].length && splits[0][$ - 1] == ':'){
			string name = splits[0][0 .. $ - 1];
			if (ret.labelNames.canFind(name))
				throw new Exception(format!"line %d: label `%s` redeclared"(
							lineNo + 1, name));
			ret.labelNames ~= name;
			ret.labels ~= ret.code.length;
			splits = splits[1 .. $];
			if (splits.length == 0)
				continue;
		}
		immutable string inst = splits[0];
		splits = splits[1 .. $];
		pass1S: switch (inst){
			static foreach (ind, Inst; T){
				case __traits(identifier, Inst):
					if (splits.length!= InstArity!Inst)
						throw new Exception(format!
								"line %d: `%s` expects %d arguments, got %d"
								(lineNo + 1, inst, InstArity!Inst, splits.length));
					ret.code ~= (cast(ushort)ind).asBytes;
					ret.code.length += InstArgsStruct!Inst.sizeof;
					break pass1S;
			}
			default:
				throw new Exception(format!"line %d: Instruction expected, got `%s`"
						(lineNo + 1, inst));
		}
		argsAll ~= splits;
	}

	// pass 2: read args
	size_t pos = 0;
	FIFOStack!string strs = new FIFOStack!string;
	size_t strsLen;
	foreach (args; argsAll){
		immutable ushort inst = ret.code[pos .. $].as!ushort;
		pos += ushort.sizeof;
		pass2S: final switch (inst){
			static foreach (ind, Inst; T){
				case ind:
					ret.code[pos .. pos + InstArgsStruct!Inst.sizeof] =
						parseArgs!Inst(ret, strs, strsLen, args).asBytes;
					pos += InstArgsStruct!Inst.sizeof;
					break pass2S;
			}
		}
	}

	// pass 3: fix strs
	InstArgsUnion!T un;
	pos = 0;
	ret.end = ret.code.length;
	size_t posE = ret.code.length;
	ret.code.length += strsLen;
	while (pos < ret.end){
		immutable ushort inst = ret.code[pos .. $].as!ushort;
		pos += ushort.sizeof;
		pass3S: final switch(inst){
			static foreach (ind, Inst; T){
				case ind:
					un.s[ind] = ret.code[pos .. $].as!(InstArgsStruct!Inst);
					static foreach (i, Arg; InstArgs!Inst){
						static if (is (Arg == string)){
							string str = strs.pop;
							ret.code[posE .. posE + str.length] = cast(ubyte[])str;
							un.s[ind].p[i] = cast(string)ret.code[posE .. posE + str.length];
							posE += str.length;
						}
					}
					ret.code[pos .. pos + InstArgsStruct!Inst.sizeof] = un.s[ind].asBytes;
					pos += InstArgsStruct!Inst.sizeof;
					break pass3S;
			}
		}
	}
	return ret;
}

private InstArgsStruct!Inst parseArgs(alias Inst)(
		ref ByteCode code, FIFOStack!string strs, ref size_t strsLen,
		string[] args){
	InstArgsStruct!Inst s;
	static foreach (i, Arg; InstArgs!Inst){
		static if (is (Arg == string)){
			if (args[i].length && args[i][0] == '"'){
				ubyte[] data = cast(ubyte[])parseData!Arg(args[i]);
				if (data == null)
					throw new Exception(format!"Instruction `%s` expected %s, got `%s`"
							(__traits(identifier, Inst), Arg.stringof, args[i]));
				strs.push(cast(string)data);
				strsLen += data.length;
			} else {
				throw new Exception(format!
						"Instruction `%s` expected string for %d-th arg, got `%s`"
						(__traits(identifier, Inst), i + 1, args[i]));
			}

		} else static if (isIntegral!Arg){
			if (args[i].length && args[i][0] == '@'){
				if (!code.labelNames.canFind(args[i][1 .. $]))
					throw new Exception(format!"Label `%s` used but not declared"
							(args[i][1 .. $]));
				s.p[i] = cast(typeof(s.p[i]))
					code.labels[code.labelNames.countUntil(args[i][1 .. $])];
			} else {
				s.p[i] = parseData!Arg(args[i]);
			}
		} else {
			s.p[i] = parseData!Arg(args[i]);
		}
	}
	return s;
}

///
/*unittest{
	void push(size_t){}
	void push2(size_t, size_t){}
	void pop(){}
	void add(){}
	void print(){}
	alias parse = parseByteCode!(push, push2, pop, add, print);
	string[] source = [
		"data: push 50",
		"start: push 50",
		"push @data",
		"push2 1 2",
		"add",
		"print"
	];
	ByteCode code = parse(source);
	assert(code.labels.length == 2);
	assert(code.labelNames.canFind("data"));
	assert(code.labelNames.canFind("start"));
	assert(code.labels[0] == [0, 0]);
	assert(code.labels[1] == [1, 8]);
	assert(code.instructions == [0, 0, 0, 1, 3, 4]);
	// tests for code.data are missing
}*/

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
/*public ubyte[] toBin(ref ByteCode code, ubyte[7] magicPostfix = 0,
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
	ByteCode code;/// empty code
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
public ByteCode fromBin(ubyte[] stream, ref ubyte[7] magicPostfix,
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

	ByteCode code;
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
	ByteCode code;
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
	ByteCode decoded = bin.fromBin(postfix, metadata);
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
}*/

/// Parses data
///	Throws: Exception if incorrect format
/// Returns: parsed data.
private T parseData(T)(string s){
	static if (isIntegral!T){
		// can be just an int
		if (isNum(s, false))
			return s.to!T;
		// can be a binary or hex literal
		if (s.length > 2 && s[0] == '0'){
			if (s[1] == 'b')
				return (cast(T)readBinary(s[2 .. $]));
			else if (s[1] == 'x')
				return (cast(T)readHexadecimal(s[2 .. $]));
		}
		throw new Exception(format!"`%s` is not an integer"(s));

	} else static if (isFloatingPoint!T){
		if (isNum(s, true))
			return s.to!T;
		throw new Exception(format!"`%s` is not a float"(s));

	} else static if (is (T == bool)){
		if (s == "true")
			return true;
		if (s == "false")
			return false;
		throw new Exception(format!"`%s` is not a boolean"(s));

	} else static if (isSomeChar!T){
		if (s.length < 2 || s[0] != s[$ - 1] || s[0] != '\'')
			return null;
		s = s[1 .. $ - 1].unescape;
		return s.to!T;

	} else static if (is (T == string)){
		if (s.length < 2 || s[0] != s[$ - 1] || s[0] != '\"')
			throw new Exception(format!"`%s` is not a string"(s));
		s = s[1 .. $ - 1].unescape;
		return s.to!T;

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
