module navm.parser;

import std.meta,
			 std.format,
			 std.traits,
			 std.array,
			 std.algorithm;

import std.conv : to;

import utils.misc : readHexadecimal, readBinary, isNum;

import navm.common,
			 navm.meta;

/// parses code from text format
/// Throws: Exception in case of errors in code
/// Returns: Code
public Code parseCode(T...)(string[] lines)
		if (allSatisfy!(isCallable, T)){
	Code ret;
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
				case InstName!Inst:
					if (splits.length!= InstArity!Inst)
						throw new Exception(format!
								"line %d: `%s` expects %d arguments, got %d"
								(lineNo + 1, inst, InstArity!Inst, splits.length));
					ret.code ~= cast(ubyte[])(cast(ushort)ind).asBytes;
					ret.code.length += SizeofSum!(InstArgs!Inst);
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
	foreach (args; argsAll){
		immutable ushort inst = ret.code[pos .. $].as!ushort;
		pos += ushort.sizeof;
		pass2S: final switch (inst){
			static foreach (ind, Inst; T){
				case ind:
					void[] updated = parseArgs!Inst(ret, args);
					ret.code[pos .. pos + SizeofSum!(InstArgs!Inst)] = updated;
					pos += SizeofSum!(InstArgs!Inst);
					break pass2S;
			}
		}
	}
	return ret;
}

private void[] parseArgs(alias Inst)(ref Code code, string[] args){
	void[] ret;
	static foreach (i, Arg; InstArgs!Inst){
		static if (is (Arg == string)){
			if (args[i].length && args[i][0] == '"'){
				void[] data = cast(ubyte[])parseData!Arg(args[i]);
				ret ~= code.data.length.asBytes;
				code.data ~= data.length.asBytes;
				code.data ~= data;
			} else {
				throw new Exception(format!
						"Instruction `%s` expected string for %d-th arg, got `%s`"
						(InstName!Inst, i + 1, args[i]));
			}

		} else static if (isIntegral!Arg){
			if (args[i].length && args[i][0] == '@'){
				if (!code.labelNames.canFind(args[i][1 .. $]))
					throw new Exception(format!"Label `%s` used but not declared"
							(args[i][1 .. $]));
				ret ~= cast(void[])(cast(Arg)
						code.labels[code.labelNames.countUntil(args[i][1 .. $])]).asBytes;
			} else {
				ret ~= cast(ubyte[])parseData!Arg(args[i]).asBytes;
			}
		} else {
			ret ~= cast(ubyte[])parseData!Arg(args[i]).asBytes;
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
	alias parse = parseCode!(push, push2, pop, add, print);
	string[] source = [
		"data: push 50",
		"start: push 50",
		"push @data",
		"push2 1 2",
		"add",
		"print"
	];
	Code code = parse(source);
	assert(code.labels.length == 2);
	assert(code.labelNames.canFind("data"));
	assert(code.labelNames.canFind("start"));
	assert(code.labels[0] == 0);
	assert(code.labels[1] == 4);
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
