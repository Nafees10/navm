module navm.navm;

import std.conv,
			 std.meta,
			 std.traits;

import navm.common;

public import navm.bytecode;

/// Execute a Code
public void execute(S, T...)(
		ref ByteCode code,
		ref S state,
		size_t label = size_t.max) if (allSatisfy!(isCallable, T)){
	size_t ic;
	if (label < code.labels.length)
		ic = code.labels[label];
	while (ic < code.end){
		immutable ushort inst = code.code[ic .. $].as!ushort;
		ic += ushort.sizeof;
		switcher: switch (inst){
			foreach (ind, Inst; T){
				case ind:
					debug{
						import std.stdio;
						writef!"calling %d %s at ic=%d; "(
								ind, __traits(identifier, Inst), ic);
						writeln(code.code[ic .. ic + InstArgsStruct!Inst.sizeof]);
					}
					{
						InstArgs!Inst p;
						static foreach (i, Arg; InstArgs!Inst){
							static if (is (Arg == string)){
								immutable size_t
									start = *(cast(size_t*)(code.code.ptr + ic)),
									end = *(cast(size_t*)(code.code.ptr + ic + size_t.sizeof));
								p[i] = cast(string)(code.code[start .. end]);
								ic += size_t.sizeof * 2;
							} else {
								p[i] = *(cast(Arg*)(code.code.ptr + ic));
								ic += Arg.sizeof;
							}
						}
						mixin(InstCallStatement!Inst);
					}
					break switcher;
			}
			default:
				break;
		}
	}
}

/// ditto
public void execute(T...)(ref ByteCode code, size_t label = size_t.max) if (
		allSatisfy!(isCallable, T) && !InstsIsStateful!T){
	ubyte dummyState;
	execute!(ubyte, T)(code, dummyState, label);
}
