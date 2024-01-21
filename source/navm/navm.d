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
	size_t ic, dc;
	if (label < code.labels.length){
		ic = code.labels[label][0];
		dc = code.labels[label][1];
	}
	InstArgsUnion!T un;
	while (ic < code.instructions.length){
		immutable ushort inst = code.instructions[ic];
		switcher: switch (inst){
			foreach (ind, Inst; T){
				case ind:
					debug{
						import std.stdio;
						writef!"calling %d %s at ic=%d dc=%d; "(
								ind, __traits(identifier, Inst), ic, dc);
						writeln(code.data[ic .. ic + InstArgsStruct!Inst.sizeof]);
					}
					un.s[ind] = code.data[dc .. $].as!(InstArgsStruct!Inst);
					ic ++;
					dc += InstArgsStruct!Inst.sizeof;
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
