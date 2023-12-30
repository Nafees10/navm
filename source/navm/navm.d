module navm.navm;

import std.conv,
			 std.meta,
			 std.traits;

import navm.common;

public import navm.bytecode;

/// Execute a ByteCode, with a shared struct of type S among instructions
public void execute(S, T...)(
		ByteCode code,
		ref S state,
		size_t label = size_t.max) if (allSatisfy!(isCallable, T)){
	size_t ic, dc;
	if (label != size_t.max){
		ic = code.labels[label][0];
		dc = code.labels[label][1];
	}
	InstArgsUnion!T pun;
	const len = code.instructions.length;
	while (ic < len){
		switcher: switch (code.instructions[ic]){
			foreach (ind, sym; T){
				case ind:
					static foreach (i; 0 .. pun.structs[ind].params.length){
						pun.structs[ind].params[i] =
							code.data[dc + SizeofSum!(pun.structs[ind].params[0 .. i]) .. $]
							.as!(typeof(pun.structs[ind].params[i]));
					}
					/*debug{
						import std.stdio;
						writef!"calling %s at ic=%d dc=%d; "(__traits(identifier, sym),
								ic, dc);
						writeln(code.data[dc .. dc + SizeofSum!(InstArgs!sym)]);
					}*/
					ic ++;
					dc += SizeofSum!(InstArgs!sym);
					mixin(InstCallStatement!sym);
					break switcher;
			}
			default:
				break;
		}
	}
}
