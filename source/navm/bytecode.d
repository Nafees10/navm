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
	string[] labelNames; /// labelNames, index corresponds `ByteCode.labels`
	size_t[] labels; /// index in code for each label
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
					ret.code.length += SizeofSum!(InstArgs!Inst);
					break pass1S;
			}
			default:
				throw new Exception(format!"line %d: Instruction expected, got `%s`"
						(lineNo + 1, inst));
		}
		argsAll ~= splits;
	}
	ret.end = ret.code.length;

	// pass 2: read args
	size_t pos = 0;
	foreach (args; argsAll){
		immutable ushort inst = ret.code[pos .. $].as!ushort;
		pos += ushort.sizeof;
		pass2S: final switch (inst){
			static foreach (ind, Inst; T){
				case ind:
					ret.code[pos .. pos + SizeofSum!(InstArgs!Inst)] =
						parseArgs!Inst(ret, args);
					pos += SizeofSum!(InstArgs!Inst);
					break pass2S;
			}
		}
	}
	return ret;
}

private ubyte[] parseArgs(alias Inst)(ref ByteCode code, string[] args){
	ubyte[] ret;
	static foreach (i, Arg; InstArgs!Inst){
		static if (is (Arg == string)){
			if (args[i].length && args[i][0] == '"'){
				ubyte[] data = cast(ubyte[])parseData!Arg(args[i]);
				if (data == null)
					throw new Exception(format!"Instruction `%s` expected %s, got `%s`"
							(__traits(identifier, Inst), Arg.stringof, args[i]));
				ret ~= code.code.length.asBytes;
				ret ~= (code.code.length + data.length).asBytes;
				code.code ~= data;
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
				ret ~= (cast(Arg)
						code.labels[code.labelNames.countUntil(args[i][1 .. $])]).asBytes;
			} else {
				ret ~= parseData!Arg(args[i]).asBytes;
			}
		} else {
			ret ~= parseData!Arg(args[i]).asBytes;
		}
	}
	return ret;
}

///
unittest{
	void push(ushort){}
	void push2(ushort, ushort){}
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
	assert(code.labels[0] == 0);
	assert(code.labels[1] == 4);
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

/// Writes ByteCode to a binary stream
///
/// Returns: binary date in a ubyte[]
public ubyte[] toBin(ref ByteCode code, ubyte[8] magicPostfix = 0,
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
	stream[7 .. 9] = ByteUnion!ushort(NAVMBC_VERSION).bytes;
	stream[9 .. 17] = magicPostfix;

	// metadata
	stream[17 .. 25] = ByteUnion!(size_t, 8)(metadata.length).bytes;
	stream[25 .. 25 + metadata.length] = metadata;
	size_t seek = 25 + metadata.length;

	// labels
	stream[seek .. seek + 8] = ByteUnion!(size_t, 8)(code.labels.length).bytes;
	seek += 8;
	foreach (i, name; code.labelNames){
		stream[seek .. seek + 8] = ByteUnion!(size_t, 8)(code.labels[i]).bytes;
		seek += 8;
		stream[seek .. seek + 8] = ByteUnion!(size_t, 8)(name.length).bytes;
		seek += 8;
		stream[seek .. seek + name.length] = cast(ubyte[])cast(char[])name;
		seek += name.length;
	}

	// instructions data
	stream[seek .. seek + 8] = ByteUnion!(size_t, 8)(code.end).bytes;
	seek += 8;
	stream[seek .. seek + code.code.length] = code.code;
	seek += code.code.length;

	return stream;
}

///
unittest{
	ByteCode code;/// empty code
	ubyte[] bin = code.toBin([1, 2, 3, 4, 5, 6, 7, 8], [8, 9, 10]);
	assert(bin.length == 17 + 8 + 3 + 8 + 8);
	assert(bin[0 .. 7] == "NAVMBC-"); // magic bytes
	assert(bin[7 .. 9] == [2, 0]); // version
	assert(bin[9 .. 17] == [1, 2, 3, 4, 5, 6, 7, 8]); // magic postfix
	assert(bin[17 .. 25] == [3, 0, 0, 0, 0, 0, 0, 0]); // length of metadata
	assert(bin[25 .. 28] == [8, 9, 10]); // metadata
}

/// Reads ByteCode from a byte stream in ubyte[]
/// Throws: Exception in case of error
/// Returns: ByteCode
public ByteCode fromBin(ubyte[] stream, ref ubyte[8] magicPostfix,
		ref ubyte[] metadata){
	if (stream.length < binStreamExpectedSize)
		throw new Exception("Stream size if less than minimum possible size");
	if (stream[0 .. 7] != "NAVMBC-")
		throw new Exception("Invalid header in stream");
	if (stream[7 .. 9] != ByteUnion!(ushort, 2)(NAVMBC_VERSION).bytes)
		throw new Exception("Stream is of different ByteCode version.\n" ~
				"\tStream: " ~ ByteUnion!ushort(stream[7 .. 9]).data.to!string ~
				"\tSupported: " ~ NAVMBC_VERSION);
	magicPostfix = stream[9 .. 17];
	size_t len = ByteUnion!(size_t, 8)(stream[17 .. 25]).data;
	if (binStreamExpectedSize(len) > stream.length)
		throw new Exception("Invalid stream length");
	metadata = stream[25 .. 25 + len];
	size_t seek = 25 + len;

	ByteCode code;

	// labels
	len = ByteUnion!(size_t, 8)(stream[seek .. seek + 8]).data;
	if (binStreamExpectedSize(metadata.length, len) > stream.length)
		throw new Exception("Invalid stream length");
	seek += 8;
	code.labels.length = len;
	code.labelNames.length = len;
	foreach (i, ref label; code.labels){
		label = ByteUnion!(size_t, 8)(stream[seek .. seek + 8]).data;
		seek += 8;
		len = ByteUnion!(size_t, 8)(stream[seek .. seek + 8]).data;
		seek += 8;
		if (seek + len > stream.length)
			throw new Exception("Invalid stream length");
		code.labelNames[i] = cast(immutable char[])stream[seek .. seek + len].dup;
		seek += len;
	}

	// data
	code.end = ByteUnion!(size_t, 8)(stream[seek .. seek + 8]).data;
	if (binStreamExpectedSize(metadata.length, code.labels.length, code.end)
			> stream.length)
		throw new Exception("Invalid stream length");
	seek += 8;
	code.code = stream[seek .. $].dup;
	return code;
}

///
unittest{
	import std.functional, std.range;
	ByteCode code;
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
	ByteCode decoded = bin.fromBin(postfix, metadata);
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
	assert("true".parseData!bool == true);
	assert("false".parseData!bool == false);
	assert("0x50".parseData!size_t == 0x50);
	assert("0b101010".parseData!size_t == 0b101010);
	assert("12345".parseData!size_t == 1_2345);
	assert("\"bla bla\"".parseData!string == "bla bla");
	assert("5.5".parseData!double == "5.5".to!double);
}
