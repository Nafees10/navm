module navm.common;

import std.meta,
			 std.conv,
			 std.traits;

/// Whether an instruction is stateful
package template InstIsStateful(alias T) if (isCallable!T){
	enum InstIsStateful = getInstIsStateful;
	private bool getInstIsStateful(){
		foreach (name; ParameterIdentifierTuple!T){
			if (name == "_state")
				return true;
		}
		return false;
	}
}

/// Whether any of the instructions in a set require state
package template InstsIsStateful(T...) if (allSatisfy!(isCallable, T)){
	private enum IsTrue(T) = T == true;
	enum InstIsStateful = anySatisfy!(IsTrue, staticMap!(InstIsStateful, T));
}

/// Whether N'th parameter of an Instruction is an argument
package template InstParamIsArg(alias T, size_t N) if (isCallable!T){
	enum InstParamIsArg =
		ParameterIdentifierTuple!T[N] != "_code" &&
		ParameterIdentifierTuple!T[N] != "_ic" &&
		ParameterIdentifierTuple!T[N] != "_state";
}

/// Instruction Function's argument types (these exclude stuff like _ic...)
package template InstArgs(alias T) if (isCallable!T){
	alias InstArgs = AliasSeq!();
	static foreach (i; 0 .. Parameters!T.length){
		static if (InstParamIsArg!(T, i))
			InstArgs = AliasSeq!(InstArgs, Parameters!T[i]);
	}
}

/// Function arity (instruction arguments only)
package template InstArity(alias T){
	enum InstArity = InstArgs!T.length;
}

/// ditto
package template InstArities(T...) if (allSatisfy!(isCallable, T)){
	alias InstArities = AliasSeq!();
	static foreach (sym; T)
		InstArities = AliasSeq!(InstArities, InstArity!sym);
}

/// If a T can be .sizeof'd
package enum HasSizeof(alias T) = __traits(compiles, T.sizeof);

/// sum of sizes
package template SizeofSum(T...) if (allSatisfy!(HasSizeof, T)){
	enum SizeofSum = calculateSizeofSum();
	private size_t calculateSizeofSum(){
		size_t ret = 0;
		foreach (sym; T)
			ret += sym.sizeof;
		return ret;
	}
}

/// Mapping of Args to Params for an instruction. size_t.max for unmapped
package template InstParamArgMapping(alias T) if (isCallable!T){
	enum InstParamArgMapping = getMapping;
	size_t[Parameters!T.length] getMapping(){
		size_t[Parameters!T.length] ret;
		size_t count = 0;
		static foreach (i; 0 .. Parameters!T.length){
			static if (InstParamIsArg!(T, i)){
				ret[i] = count ++;
			} else {
				ret[i] = size_t.max;
			}
		}
		return ret;
	}
}

/// Instruction's Parameters alias for calling
package template InstCallStatement(alias Inst) if (isCallable!Inst){
	enum InstCallStatement = getStatement();
	private string getStatement(){
		string ret = "Inst(";
		static foreach (i, mapTo; InstParamArgMapping!Inst){
			static if (mapTo == size_t.max){
				static if (ParameterIdentifierTuple!Inst[i] == "_ic"){
					ret ~= "ic, ";
				} else static if (ParameterIdentifierTuple!Inst[i] == "_state"){
					ret ~= "state, ";
				} else static if (ParameterIdentifierTuple!Inst[i] == "_code"){
					ret ~= "code, ";
				}
			} else {
				ret ~= "p[" ~ mapTo.to!string ~ "], ";
			}
		}
		if (ret[$ - 1] == '(')
			return ret ~ ");";
		return ret[0 .. $ - 2] ~ ");";
	}
}


/// Union with array of ubytes
package union ByteUnion(T, ubyte N = T.sizeof){
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


/// Reads a ubyte[] as a type
/// Returns: value in type T
pragma(inline, true) package T as(T)(ubyte[] data) {
	assert(data.length >= T.sizeof);
	return *(cast(T*)data.ptr);
}

/// Returns: ubyte[] against a value of type T
pragma(inline, true) package ubyte[] asBytes(T)(T val) {
	ubyte[] ret;
	ret.length = T.sizeof;
	return ret[] = (cast(ubyte*)&val)[0 .. T.sizeof];
}

///
unittest{
	assert((cast(ptrdiff_t)1025).asBytes.as!ptrdiff_t == 1025);
	assert("hello".asBytes.as!string == "hello");
	assert((cast(double)50.5).asBytes.as!double == 50.5);
	assert('a'.asBytes.as!char == 'a');
	assert(true.asBytes.as!bool == true);
}


/// reads a string into substrings separated by whitespace. Strings are read
/// as a whole
///
/// Returns: substrings
///
/// Throws: Exception if string not closed
package string[] separateWhitespace(string line){
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
package ptrdiff_t strEnd(string s){
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
package string unescape(string s){
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
