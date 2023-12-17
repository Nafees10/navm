module navm.bytecode;

import utils.ds,
			 utils.misc;

import std.conv,
			 std.uni,
			 std.array,
			 std.algorithm;

public struct ByteCode{
	uint[2][string] labels; /// [codeIndex, dataIndex] for each labal
	ushort[] instructions; /// instruction codes
	NaData[] data; /// instruction data
}

/// For storing data of varying data types
public struct NaData{
	/// the actual data
	ubyte[] argData;

	@disable this();
	this(T)(T val){
		static if (is (T == string)){
			argData = cast(ubyte[])(cast(char[])val);
		} else {
			argData.length = T.sizeof;
			argData[0 .. T.sizeof] = (cast(ubyte*)&val)[0 .. T.sizeof];
		}
	}

	/// value. ** do not use this for arrays, aside from string **
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

/// reads a string into substrings separated by whitespace. Strings are read
/// as a whole
///
/// Returns: substrings
///
/// Throws: Exception if string not closed
private string[] separateWhitespace(string line){
	string[] r;
	for (size_t i, readFrom; i < line.length; i++){
		immutable char c = line[i];
		if (c == '#'){
			if (readFrom < i)
				r ~= line[readFrom .. i];
			break;
		}
		if (c == '"' || c == '\''){
			if (readFrom < i)
				r ~= line[readFrom .. i];
			readFrom = i;
			immutable ptrdiff_t endIndex = i + line[i .. $].strEnd;
			if (endIndex < 0)
				throw new Exception("string not closed");
			r ~= line[readFrom .. endIndex + 1];
			readFrom = endIndex + 1;
			i = endIndex;
			continue;
		}

		if (c == ' ' || c == '\t'){
			if (readFrom < i)
				r ~= line[readFrom .. i];
			while (i < line.length && (line[i] == ' ' || line[i] == '\t'))
				i ++;
			readFrom = i;
			i --; // back to whitespace, i++ in for(..;..;) exists
			continue;
		}

		if (i + 1 == line.length && readFrom <= i)
			r ~= line[readFrom .. $].dup;
	}
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

/// ditto
private string[][] separateWhitespace(string[] lines){
	return lines.map!(a => a.separateWhitespace).array;
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
private string strUnescape(string s){
	if (s.length == 0)
		return null;
	char[] r = [];
	for (size_t i = 0, end = s.length - 1; i < end; i ++){
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
	assert("newline:\\ntab:\\t".strUnescape == "newline:\ntab:\t", "newline:\\ntab:\\t".strUnescape);
}
