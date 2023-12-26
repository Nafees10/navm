module navm.bytecode;

import utils.misc : readHexadecimal, readBinary, isNum;

import std.conv,
			 std.uni,
			 std.array,
			 std.string,
			 std.algorithm;

public struct ByteCode{
	string[] labelNames; /// label index against each labelName
	size_t[2][] labels; /// [codeIndex, dataIndex] for each labal
	ushort[] instructions; /// instruction codes
	ubyte[] data; /// instruction data
}

/// ByteCode version
public enum ushort NAVMBC_VERSION = 0x02;

/// Reads a ubyte[] as a type
/// Returns: value in type T
pragma(inline, true)
public T as(T)(ubyte[] data){
	static if (is (T == string)){
		return cast(string)cast(char[])data;
	} else {
		assert(data.length >= T.sizeof);
		return *(cast(T*)data.ptr);
	}
}

/// Returns: ubyte[] against a value of type T
pragma(inline, true)
public ubyte[] asBytes(T)(T val){
	static if (is (T == string)){
		return cast(ubyte[])cast(char[])val;
	} else {
		ubyte[] ret;
		ret.length = T.sizeof;
		return ret[] = (cast(ubyte*)&val)[0 .. T.sizeof];
	}
}

///
unittest{
	assert((cast(ptrdiff_t)1025).asBytes.as!ptrdiff_t == 1025);
	assert("hello".asBytes.as!string == "hello");
	assert((cast(double)50.5).asBytes.as!double == 50.5);
	assert('a'.asBytes.as!char == 'a');
	assert(true.asBytes.as!bool == true);
}

package ByteCode parseByteCode(
		string[] Insts,
		uint[] InstArgC)
	(
		string[] lines){
	ByteCode ret;
	size_t[] absPos = [0];
	size_t[] toResolveAddr;
	string[] toResolveArg;

	foreach (i, line; lines){
		string[] splits = line.separateWhitespace.filter!(a => a.length > 0).array;
		if (splits.length == 0)
			continue;
		if (splits[0].length && splits[0][$ - 1] == ':'){
			string name = splits[0][0 .. $ - 1];
			if (ret.labelNames.canFind(name))
				throw new Exception("line " ~ (i + 1).to!string ~
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
			static foreach (ind, name; Insts){
				case name:
					if (cast(ptrdiff_t)splits.length - 1 != InstArgC[ind])
						throw new Exception("line " ~ (i + 1).to!string ~ ": " ~ name ~
								" instruction expects " ~ InstArgC[ind].to!string ~
								" arguments, got " ~ (splits.length - 1).to!string);
					ret.instructions ~= ind;
					break caser;
			}
			default:
				throw new Exception("line " ~ (i + 1).to!string ~
						": Instruction expected, got `" ~ splits[0] ~ "`");
		}

		splits = splits[1 .. $];
		foreach (split; splits){
			if (split.length && split[0] == '@'){
				toResolveArg ~= split[1 .. $];
				toResolveAddr ~= ret.data.length;
				ret.data.length += size_t.sizeof;
				absPos ~= absPos[$ - 1] + size_t.sizeof;
				continue;
			}
			ubyte[] data = parseData(split);
			if (data == null)
				throw new Exception("line " ~ (i + 1).to!string ~ ": Invalid data `" ~
						split ~ "`");
			ret.data ~= data;
			absPos ~= absPos[$ - 1] + data.length;
		}
	}

	// resolve addresses
	foreach (ind, index; toResolveAddr){
		string arg = toResolveArg[ind];
		ptrdiff_t plusInd = arg.indexOf('+');
		// its a data address
		if (plusInd != -1){
			string label = arg[0 .. plusInd];
			size_t offset = size_t.max;
			try {
				offset = arg[plusInd + 1 .. $].to!size_t;
			} catch (Exception){}
			if (offset == size_t.max || (
						label.length && !ret.labelNames.canFind(label)))
				throw new Exception("Invalid address `" ~ arg ~ "`");
			size_t pos = offset +
				(label.length ? ret.labels[ret.labelNames.countUntil(label)][1] : 0);
			if (pos > absPos.length)
				throw new Exception("Invalid offset `" ~ arg ~ "`");
			ret.data[index .. index + size_t.sizeof] = absPos[pos].asBytes;
			continue;
		}
		// its a label address
		if (!ret.labelNames.canFind(arg))
			throw new Exception("Invalid address `" ~ arg ~ "`");
		ret.data[index .. index + size_t.sizeof] =
			ret.labelNames.countUntil(arg).asBytes;
	}
	return ret;
}

///
unittest{
	alias parse = parseByteCode!(
			["push", "push2", "pop", "add", "print"],
			[1, 2, 1, 0, 0]);
	string[] source = [
		"data: push 50",
		"start: push 50",
		"push @data+2",
		"push2 1 2",
		"add",
		"print"
	];
	ByteCode code = parse(source);
	import std.stdio;
	assert(code.labels.length == 2);
	assert(code.labelNames.canFind("data"));
	assert(code.labelNames.canFind("start"));
	assert(code.labels[0] == [0, 0]);
	assert(code.labels[1] == [1, 8]);
	assert(code.instructions == [0, 0, 0, 1, 3, 4]);
	// tests for code.data are missing
}

/// Union with array of ubytes
private union ByteUnion(T, ubyte N = T.sizeof){
	T data;
	ubyte[N] bytes;
	this(ubyte[N] bytes){
		this.bytes = bytes;
	}
	this(ubyte[] bytes){
		assert(bytes.length >= N);
		this.bytes = bytes[0 .. N];
	}
	this(T data){
		this.data = data;
	}
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
public ubyte[] toBin(ref ByteCode code, ubyte[7] magicPostfix = 0,
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
}

/// Parses data, asBytes it into ubyte[].
///
/// Returns: resulting ubyte[], or `null` if invalid or address or label
private ubyte[] parseData(string s){
	assert(s.length);
	if (isNum(s, true)){
		if (isNum(s, false))
			return s.to!ptrdiff_t.asBytes;
		return s.to!double.asBytes;
	}
	if (s.length > 2 && s[0] == '0'){
		try{
			if (s[1] == 'b')
				return (cast(ptrdiff_t)readBinary(s[2 .. $])).asBytes;
			else if (s[1] == 'x')
				return (cast(ptrdiff_t)readHexadecimal(s[2 .. $])).asBytes;
		} catch (Exception){
			return null;
		}
	}
	if (s == "true")
		return true.asBytes;
	if (s == "false")
		return false.asBytes;
	if (s[0] == '"' || s[0] == '\'')
		return s[1 .. $ - 1].unescape.asBytes;
	if (s[0] != '@')
		return null;
	return s.asBytes;
}

///
unittest{
	assert("true".parseData.as!bool == true);
	assert("false".parseData.as!bool == false);
	assert("0x50".parseData.as!size_t == 0x50);
	assert("0b101010".parseData.as!size_t == 0b101010);
	assert("12345".parseData.as!size_t == 1_2345);
	assert("\"bla bla\"".parseData.as!string == "bla bla");
	assert("5.5".parseData.as!double == "5.5".to!double);
}

/// reads a string into substrings separated by whitespace. Strings are read
/// as a whole
///
/// Returns: substrings
///
/// Throws: Exception if string not closed
private string[] separateWhitespace(string line){
	string[] r;
	size_t i, start;
	for (; i < line.length; i++){
		immutable char c = line[i];
		if (c == '#'){
			if (start < i)
				r ~= line[start .. i];
			break;
		}
		if (c == '"' || c == '\''){
			if (start < i)
				r ~= line[start .. i];
			start = i;
			immutable ptrdiff_t endIndex = i + line[i .. $].strEnd;
			if (endIndex <= i)
				throw new Exception("string not closed");
			r ~= line[start .. endIndex + 1];
			start = endIndex + 1;
			i = endIndex;
			continue;
		}

		if (c == ' ' || c == '\t'){
			if (start < i)
				r ~= line[start .. i];
			while (i < line.length && (line[i] == ' ' || line[i] == '\t'))
				i ++;
			start = i;
			i --; // back to whitespace, i++ in for(..;..;) exists
			continue;
		}

	}
	if (i == line.length && start <= i - 1)
		r ~= line[start .. $].dup;
	return r;
}
///
unittest{
	assert("potato".separateWhitespace == ["potato"]);
	assert("potato potato".separateWhitespace == ["potato", "potato"]);
	assert(" a b \"str\"".separateWhitespace == ["a", "b", "\"str\""]);
	assert("a b 'c' \"str\"".separateWhitespace == ["a", "b", "'c'", "\"str\""]);
	assert("\ta   \t b\"str\"".separateWhitespace == ["a", "b", "\"str\""]);
	assert("   a   b  'c'\"str\"'c'".separateWhitespace ==
			["a", "b", "'c'", "\"str\"", "'c'"]);
	assert("a 'b'#c".separateWhitespace == ["a", "'b'"]);
	assert("a: a b#c".separateWhitespace == ["a:","a", "b"]);
	assert("a 'b' #c".separateWhitespace == ["a", "'b'"]);
}

/// Returns: the index where a string ends, -1 if not terminated
private ptrdiff_t strEnd(string s){
	if (s.length == 0)
		return -1;
	immutable char strTerminator = s[0];
	size_t i;
	for (i = 1; i < s.length; i ++){
		if (s[i] == strTerminator)
			return i;
		i += s[i] == '\\';
	}
	return -1;
}
///
unittest{
	assert(2 + "st\"sdfsdfsd\"0"[2 .. $].strEnd == 11);
}

/// Returns: unescaped string
private string unescape(string s){
	if (s.length == 0)
		return null;
	char[] r = [];
	for (size_t i = 0; i < s.length; i ++){
		if (s[i] != '\\'){
			r ~= s[i];
			continue;
		}
		if (i + 1 < s.length){
			char c = s[i + 1];
			switch (c){
				case 't': r ~= '\t'; i ++; continue;
				case 'n': r ~= '\n'; i ++; continue;
				case '\\': r ~= '\\'; i ++; continue;
				default: break;
			}
		}
		r ~= s[i];
	}
	return cast(string)r;
}
///
unittest{
	assert("newline:\\ntab:\\t".unescape ==
			"newline:\ntab:\t", "newline:\\ntab:\\t".unescape);
}
