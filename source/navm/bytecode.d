module navm.bytecode;

import utils.ds,
			 utils.misc;

import std.conv,
			 std.uni,
			 std.array,
			 std.algorithm;

public struct ByteCode{
	string[] labelNames; /// label index against each labelName
	size_t[2][] labels; /// [codeIndex, dataIndex] for each labal
	ushort[] instructions; /// instruction codes
	ubyte[] data; /// instruction data
}

/// Reads a ubyte[] as a type
/// Returns: value in type T
pragma(inline, true);
public T as(T)(ubyte[] data){
	static if (is (T == string)){
		return cast(string)cast(char[])data;
	} else {
		assert(data.length >= T.sizeof);
		return *(cast(T*)data.ptr);
	}
}

/// Returns: ubyte[] against a value of type T
pragma(inline, true);
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
				(label.length ? ret.labels[ret.labelNames.indexOf(label)][1] : 0);
			if (pos > absPos.length)
				throw new Exception("Invalid offset `" ~ arg ~ "`");
			ret.data[index .. index + size_t.sizeof] = absPos[pos].asBytes;
			continue;
		}
		// its a label address
		if (!ret.labelNames.canFind(arg))
			throw new Exception("Invalid address `" ~ arg ~ "`");
		ret.data[index .. index + size_t.sizeof] =
			ret.labelNames.indexOf(arg).asBytes;
	}
	return ret;
}

///
unittest{
	alias parse = parseByteCode!(
			["push", "pop", "add", "print"],
			[1, 1, 0, 0]);
	string[] source = [
		"data: push 50",
		"start: push 50",
		"push @data+2",
		"add",
		"print"
	];
	ByteCode code = parse(source);
	import std.stdio;
	assert(code.labels.length == 2);
	assert("data" in code.labels);
	assert("start" in code.labels);
	assert(code.labels["data"] == [0, 0]);
	assert(code.labels["start"] == [1, 8]);
	assert(code.instructions == [0, 0, 0, 2, 3]);
	// tests for code.data are missing
}

// TODO implement binary file read/write

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
