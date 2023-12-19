module navm.bytecode;

import utils.ds,
			 utils.misc;

import std.conv,
			 std.uni,
			 std.array,
			 std.string,
			 std.algorithm;

public struct ByteCode{
	uint[2][string] labels; /// [codeIndex, dataIndex] for each labal
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
				absPos[$ - 1]
			];
			splits = splits[1 .. $];
			if (splits.length == 0)
				continue;
		}

		switch (splits[0]){
			static foreach (ind, name; Insts){
				case name:
					if (cast(ptrdiff_t)splits.length - 1 != InstArgC[ind])
						throw new Exception("line " ~ i.to!string ~ ": " ~ name ~
								" instruction expects " ~ InstArgC[ind].to!string ~
								" arguments, got " ~ splits.length - 1);
					ret.instructions ~= InstCodes[ind];
					break;
			}
			default:
				throw new Exception("line " ~ i.to!string ~ ": Instruction expected");
				break;
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
		string plusInd = arg.indexOf('+');
		// its a data address
		if (plusInd != -1){
			string label = arg[0 .. plusInd];
			size_t offset = size_t.max;
			try{
				offset = arg[plusInd + 1 .. $].to!size_t;
			}catch (Exception){}
			if (offset == size_t.max || label !in ret.labels)
				throw new Exception("Invalid Address `" ~ arg ~ "`");
			ret.data[index] = NaData(ret.labels[label][1] + offset);
			continue;
		}
		// its a label address
		if (arg !in ret.labels)
			throw new Exception("Invalid Address `" ~ arg ~ "`");
		ret.data[index] = NaData(ret.labels[arg][0]);
	}
	return ret;
}

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
			if (s[2] == 'b')
				return NaData(cast(ptrdiff_t)readBinary(s[2 .. $]));
			else if (s[2] == 'x')
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
	for (size_t i = 0, end = cast(ptrdiff_t)s.length - 1; i < end; i ++){
		if (s[i] != '\\'){
			r ~= s[i];
			continue;
		}
		char c = s[i + 1];
		switch (c){
			case 't': r ~= '\t'; i ++; continue;
			case 'n': r ~= '\n'; i ++; continue;
			case '\\': r ~= '\\'; i ++; continue;
			default: break;
		}
		r ~= s[i];
	}
	return cast(string)r;
}
///
unittest{
	assert("newline:\\ntab:\\t".unescape == "newline:\ntab:\t", "newline:\\ntab:\\t".strUnescape);
}
