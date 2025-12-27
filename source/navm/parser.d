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
	ret.end = ret.code.length;

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
				if (data == null)
					throw new Exception(format!"Instruction `%s` expected %s, got `%s`"
							(InstName!Inst, Arg.stringof, args[i]));
				ret ~= code.code.length.asBytes;
				ret ~= (code.code.length + data.length).asBytes;
				code.code ~= data;
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
