module navm.navm;

import std.conv,
			 std.meta,
			 std.traits;

import navm.common;

public import navm.bytecode;

/// Execute a ByteCode
public void execute(S, T...)(
		ref ByteCode code,
		ref S state,
		size_t label = size_t.max) if (allSatisfy!(isCallable, T)){
	size_t ic, dc;
	if (label != size_t.max){
		ic = code.labels[label][0];
		dc = code.labels[label][1];
	}
	InstArgsUnion!T un;
	const len = code.instructions.length;
	while (ic < len){
		switcher: switch (code.instructions[ic]){
			foreach (ind, Inst; T){
				case ind:
					/*debug{
						import std.stdio;
						writef!"calling %d %s at ic=%d dc=%d; "(
								ind, __traits(identifier, Inst), ic, dc);
						writeln(code.data[dc .. dc + SizeofSum!(InstArgs!Inst)]);
					}*/
					static foreach (i, Arg; InstArgs!Inst){
						static if (isSomeString!Arg){
							immutable size_t p = code.data
								[dc .. dc + size_t.sizeof].as!size_t;
							immutable size_t c = code.data
								[size_t.sizeof + dc .. dc + 2 * size_t.sizeof].as!size_t;
							un.s[ind].p[i] =
								(cast(ForeachType!Arg*)(code.data[p .. $].ptr))
								[0 .. (c / ForeachType!Arg.sizeof)];
						} else {
							un.s[ind].p[i] =
								code.data[
								dc + SizeofSum!(un.s[ind].p[0 .. i]) .. $].as!Arg;
						}
					}
					ic ++;
					dc += SizeofSum!(InstArgs!Inst);
					mixin(InstCallStatement!Inst);
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
