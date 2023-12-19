module navm.bytecode;

import utils.ds,
			 utils.misc;

import std.conv,
			 std.uni,
			 std.array,
			 std.algorithm;

public struct ByteCode{
	size_t[2][string] labels; /// [codeIndex, dataIndex] for each labal
	ushort[] instructions; /// instruction codes
	NaData[] data; /// instruction data
}

/// For storing data of varying data types
public struct NaData{
	/// the actual data
	ubyte[] argData = null;

	this(T)(T val){
		static if (is (T == string)){
			argData = cast(ubyte[])(cast(char[])val);
		} else {
			argData.length = T.sizeof;
			argData[0 .. T.sizeof] = (cast(ubyte*)&val)[0 .. T.sizeof];
		}
	}

	/// value. **do not use this for arrays, aside from string**
	@property T value(T)(){
		static if (is (T == string)){
			return cast(string)cast(char[])argData;
		} else {
			if (argData.length < T.sizeof)
				assert(false, "NaData.value.argData.length < T.sizeof");
			return *(cast(T*)argData.ptr);
		}
	}
}
///
unittest{
	assert(NaData(cast(ptrdiff_t)1025).value!ptrdiff_t == 1025);
	assert(NaData("hello").value!string == "hello");
	assert(NaData(cast(double)50.5).value!double == 50.5);
	assert(NaData('a').value!char == 'a');
	assert(NaData(true).value!bool == true);
}

public ByteCode parseByteCode(
		string[] Insts,
		uint[] InstArgC,
		ushort[] InstCodes)
	(
		string[] lines){
	ByteCode ret;
	size_t[] absPos = [0];
	size_t[] toResolve; /// indexes of datas to be resolved

	foreach (i, line; lines){
		string[] splits = line.separateWhitespace;
		if (splits.length == 0)
			continue;
		if (splits[0][$ - 1] == ':'){
			ret.labels[splits[0][0 .. $ - 1]] = [
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
						throw new Exception("line " ~ i.to!string ~ ": " ~ name ~
								" instruction expects " ~ InstArgC[ind].to!string ~
								" arguments, got " ~ (splits.length - 1).to!string);
					ret.instructions ~= InstCodes[ind];
					break caser;
			}
			default:
				throw new Exception("line " ~ i.to!string ~ ": Instruction expected");
				break caser;
		}
		splits = splits[1 .. $];
		foreach (split; splits){
			if (split.length && split[0] == '@'){
				toResolve ~= ret.data.length;
				ret.data ~= NaData(split);
				absPos ~= absPos[$ - 1] + size_t.sizeof;
				continue;
			}
			NaData data = parseData(split);
			if (data.argData == null)
				throw new Exception("line " ~ i.to!string ~ ": Invalid data `" ~
						split ~ "`");
			ret.data ~= data;
			absPos ~= absPos[$ - 1] + data.argData.length;
		}
	}

	// resolve addresses
	foreach (index; toResolve){
		string arg = ret.data[index].value!string[1 .. $];
		ptrdiff_t plusInd = arg.indexOf('+');
		// its a data address
		if (plusInd != -1){
			string label = arg[0 .. plusInd];
			size_t offset = size_t.max;
			try{
				offset = arg[plusInd + 1 .. $].to!size_t;
			}catch (Exception){}
			if (offset == size_t.max || label !in ret.labels)
				throw new Exception("Invalid address `" ~ arg ~ "`");
			size_t pos = ret.labels[label][1] + offset;
			if (pos > absPos.length)
				throw new Exception("Invalid offset `" ~ arg ~ "`");
			ret.data[index] = NaData(absPos[pos]);
			continue;
		}
		// its a label address
		if (arg !in ret.labels)
			throw new Exception("Invalid address `" ~ arg ~ "`");
		ret.data[index] = NaData(ret.labels[arg][0]);
	}

	// resolve label data indexes to data addresses using absPos
	foreach (label; ret.labels.keys)
		ret.labels[label][1] = absPos[ret.labels[label][1]];
	return ret;
}

///
unittest{
	alias parse = parseByteCode!(
			["push", "pop", "add", "print"],
			[1, 1, 0, 0],
			[1, 2, 3, 4]);
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
	assert(code.instructions == [1, 1, 1, 3, 4]);
	// tests for code.data are missing
}

// TODO implement binary file read/write

/// Parses data into NaData.
///
/// Returns: resulting NaData, or `NaData()` if invalid or address or label
private NaData parseData(string s){
	assert(s.length);
	if (isNum(s, true)){
		if (isNum(s, false))
			return NaData(s.to!ptrdiff_t);
		return NaData(s.to!double);
	}
	if (s.length > 2 && s[0] == '0'){
		try{
			if (s[1] == 'b')
				return NaData(cast(ptrdiff_t)readBinary(s[2 .. $]));
			else if (s[1] == 'x')
				return NaData(cast(ptrdiff_t)readHexadecimal(s[2 .. $]));
		} catch (Exception){
			return NaData();
		}
	}
	if (s == "true")
		return NaData(true);
	if (s == "false")
		return NaData(false);
	if (s[0] == '"' || s[0] == '\'')
		return NaData(s[1 .. $ - 1].unescape);
	if (s[0] != '@')
		return NaData();
	return NaData(s);
}

///
unittest{
	assert("true".parseData.value!bool == true);
	assert("false".parseData.value!bool == false);
	assert("0x50".parseData.value!size_t == 0x50);
	assert("0b101010".parseData.value!size_t == 0b101010);
	assert("12345".parseData.value!size_t == 1_2345);
	assert("\"bla bla\"".parseData.value!string == "bla bla");
	assert("5.5".parseData.value!double == "5.5".to!double);
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
	assert("   a   b  'c'\"str\"'c'".separateWhitespace == ["a", "b", "'c'", "\"str\"", "'c'"]);
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
