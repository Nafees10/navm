module navm.common;

/// ByteCode version
public enum ushort NAVMBC_VERSION = 0x0003;

/// ByteCode
public struct Code{
	string[] labelNames; /// labelNames, index corresponds `labels`
	size_t[] labels; /// index in code for each label
	void[] code; /// instructions and their data
	size_t end; /// index+1 of last instruction in code
}

package:

/// Reads a void[] as a type
/// Returns: value in type T
pragma(inline, true) inout(T) as(T)(inout void[] data) pure {
	assert(data.length >= T.sizeof);
	return *(cast(T*)data.ptr);
}

/// Returns: void[] against a value of type T
pragma(inline, true) void[] asBytes(T)(T val) pure {
	void[] ret;
	ret.length = T.sizeof;
	return ret[] = (cast(void*)&val)[0 .. T.sizeof];
}


/// reads a string into substrings separated by whitespace. Strings are read
/// as a whole
///
/// Returns: substrings
///
/// Throws: Exception if string not closed
string[] separateWhitespace(string line){
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
ptrdiff_t strEnd(string s){
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
string unescape(string s){
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
