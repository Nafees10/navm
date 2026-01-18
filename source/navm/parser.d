module navm.parser;

import std.meta : allSatisfy;
import std.traits : isCallable, isIntegral, isFloatingPoint;

import navm.common;
import navm.error;
import navm.meta;

/// parses code from text format
/// Returns: Code or Err
public ErrVal!Code parseCode(T...)(string[] lines)
		if (allSatisfy!(isCallable, T)){
	Code ret;
	string[][] argsAll;

	// pass 1: split args, and read labels
	foreach (lineNo, line; lines){
		string[] splits = line.separateWhitespace.val;
		if (splits.length == 0) continue;
		if (splits[0].length && splits[0][$ - 1] == ':'){
			string name = splits[0][0 .. $ - 1];
			if (ret.labelNames.canFind(name))
				return ErrVal!Code(Err.Type.LabelRedeclare.Err(name));
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
					if (splits.length != InstArity!Inst)
						return ErrVal!Code(Err.Type.InstructionArgCountInvalid.Err(inst));
					ret.code ~= cast(ubyte[])(cast(ushort)ind).asBytes;
					ret.code.length += SizeofSum!(InstArgs!Inst);
					break pass1S;
			}
			default:
				return ErrVal!Code(Err.Type.InstructionExpected.Err(inst));
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
					ErrVal!(void[]) updated = parseArgs!Inst(ret, args);
					if (updated.isErr)
						return ErrVal!Code(updated.err);
					ret.code[pos .. pos + SizeofSum!(InstArgs!Inst)] = updated.val;
					pos += SizeofSum!(InstArgs!Inst);
					break pass2S;
			}
		}
	}
	return ret.ErrVal!Code;
}

private ErrVal!(void[]) parseArgs(alias Inst)(ref Code code, string[] args){
	void[] ret;
	static foreach (i, Arg; InstArgs!Inst){
		static if (is (Arg == string)){
			if (args[i].length && args[i][0] == '"'){
				ErrVal!string data = parseData!string(args[i]);
				if (data.isErr)
					return data.err.ErrVal!(void[]);
				ret ~= code.data.length.asBytes;
				code.data ~= data.length.asBytes;
				code.data ~= cast(ubyte[])(data.val);
			} else {
				return ErrVal!(void[])(Err.Type.InstructionArgInvalid.Err(args[i]));
			}

		} else static if (isIntegral!Arg){
			if (args[i].length && args[i][0] == '@'){
				if (!code.labelNames.canFind(args[i][1 .. $]))
					return ErrVal!(void[])(Err.Type.LabelUndefined.Err(args[i][1 .. $]));
				ret ~= cast(void[])(cast(Arg)
						code.labels[code.labelNames.indexOf(args[i][1 .. $])]).asBytes;
			} else {
				ErrVal!Arg convd = parseData!Arg(args[i]);
				if (convd.isErr)
					return convd.err.ErrVal!(void[]);
				ret ~= cast(ubyte[])convd.val.asBytes;
			}
		} else {
			ErrVal!Arg convd = parseData!Arg(args[i]);
			if (convd.isErr)
				return convd.err.ErrVal!(void[]);
			ret ~= cast(ubyte[])convd.val.asBytes;
		}
	}
	return ErrVal!(void[])(ret);
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
/// Returns: parsed data or Err
private ErrVal!T parseData(T)(string s){
	static if (isIntegral!T){
		// can be just an int
		if (isNum(s, false))
			return s.parseInt!T.ErrVal!T;
		// can be a binary or hex literal
		if (s.length > 2 && s[0] == '0'){
			if (s[1] == 'b'){
				s = s[2 .. $];
				if (!isBinInt(s))
					return ErrVal!T(Err.Type.ValueNotBin.Err);
				return (cast(T)parseBinInt(s)).ErrVal!T;
			} else if (s[1] == 'x'){
				s = s[2 .. $];
				if (!isHexInt(s))
					return ErrVal!T(Err.Type.ValueNotHex.Err);
				return (cast(T)parseHexInt(s)).ErrVal!T;
			}
		}
		return ErrVal!T(Err.Type.ValueNotInt.Err(s));

	} else static if (isFloatingPoint!T){
		if (isNum(s, true))
			return s.parseFloat!T.ErrVal!T;
		return ErrVal!T(Err.Type.ValueNotFloat.Err(s));

	} else static if (is (T == bool)){
		if (s == "true")
			return true.ErrVal!T;
		if (s == "false")
			return false.ErrVal!T;
		return ErrVal!T(Err.Type.ValueNotBool.Err(s));

	} else static if (is (T == char)){
		if (s.length < 2 || s[0] != s[$ - 1] || s[0] != '\'' || s.length > 4)
			return ErrVal!T(Err.Type.ValueNotFloat.Err);
		s = s[1 .. $ - 1].unescape;
		if (s.length > 1)
			return ErrVal!T(Err.Type.ValueNotFloat.Err);
		return s[0].ErrVal!T;

	} else static if (is (T == string)){
		if (s.length < 2 || s[0] != s[$ - 1] || s[0] != '\"')
			return ErrVal!T(Err.Type.ValueNotString.Err(s));
		s = s[1 .. $ - 1].unescape;
		return s.ErrVal!T;

	} else {
		static assert(false, "Unsupported argument type " ~ T.stringof);
	}
}

///
unittest{
	assert("true".parseData!bool.val == true);
	assert("false".parseData!bool.val == false);
	assert("0x50".parseData!size_t.val == 0x50);
	assert("0b101010".parseData!size_t.val == 0b101010);
	assert("12345".parseData!size_t.val == 1_2345);
	assert("\"bla bla\"".parseData!string.val == "bla bla");
	assert("5.5".parseData!double.val == 5.5);
}

/// reads a string into substrings separated by whitespace. Strings are read
/// as a whole
///
/// Returns: substrings or err
private ErrVal!(string[]) separateWhitespace(string line){
	string[] r;
	size_t i, start;
	for (; i < line.length; i++){
		immutable char c = line[i];
		if (c == '#'){
			if (start < i)
				if (!line[start .. i].isWhite)
					r ~= line[start .. i];
			break;
		}
		if (c == '"' || c == '\''){
			if (start < i && !line[start .. i].isWhite)
				r ~= line[start .. i];
			start = i;
			immutable ptrdiff_t endIndex = i + line[i .. $].strEnd;
			if (endIndex <= i)
				return ErrVal!(string[])(Err.Type.StringNotClosed.Err);
			r ~= line[start .. endIndex + 1];
			start = endIndex + 1;
			i = endIndex;
			continue;
		}

		if (c == ' ' || c == '\t'){
			if (start < i && !line[start .. i].isWhite)
				r ~= line[start .. i];
			while (i < line.length && (line[i] == ' ' || line[i] == '\t'))
				i ++;
			start = i;
			i --; // back to whitespace, i++ in for(..;..;) exists
			continue;
		}

	}
	if (i == line.length && start <= i - 1 && !line[start .. $].isWhite)
		r ~= line[start .. $].duplicate;
	return r.ErrVal!(string[]);
}
///
unittest{
	assert("potato".separateWhitespace.val == ["potato"]);
	assert("potato potato".separateWhitespace.val == ["potato", "potato"]);
	assert(" a b \"str\"".separateWhitespace.val == ["a", "b", "\"str\""]);
	assert("a b 'c' \"str\"".separateWhitespace.val ==
			["a", "b", "'c'", "\"str\""]);
	assert("\ta   \t b\"str\"".separateWhitespace.val == ["a", "b", "\"str\""]);
	assert("   a   b  'c'\"str\"'c'".separateWhitespace.val ==
			["a", "b", "'c'", "\"str\"", "'c'"]);
	assert("a  'b'#c".separateWhitespace.val == ["a", "'b'"]);
	assert("a: a b#c".separateWhitespace.val == ["a:","a", "b"]);
	assert("a 'b' #c".separateWhitespace.val == ["a", "'b'"]);
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
