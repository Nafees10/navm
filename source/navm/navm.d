module navm.navm;

import std.conv,
			 std.meta,
			 std.traits;

public import navm.bytecode;

/// Parse string[] lines into bytecode
/// Template parameters are functions for instructions
/// Throws: Exception on invalid bytecode
/// Returns: ByteCode
public alias parseByteCode(T...) = navm.bytecode.parseByteCode!(
		[InstNames!T], [InstArities!T]);

/// Function names
private template InstNames(T...) if (allSatisfy!(isCallable, T)){
	alias InstNames = AliasSeq!();
	static foreach (sym; T)
		InstNames = AliasSeq!(InstNames, __traits(identifier, sym));
}

/// Whether N'th parameter of an Instruction is an argument
private template InstParamIsArg(alias T, size_t N) if (isCallable!T){
	enum InstParamIsArg =
		!is (Parameters!T[N] == navm.bytecode.ByteCode) &&
		ParameterIdentifierTuple!T[N] != "_ic" &&
		ParameterIdentifierTuple!T[N] != "_dc" &&
		ParameterIdentifierTuple!T[N] != "_state";
}

/// Instruction Function's argument types (these exclude stuff like _ic...)
private template InstArgs(alias T) if (isCallable!T){
	alias InstArgs = AliasSeq!();
	static foreach (i; 0 .. Parameters!T.length){
		static if (InstParamIsArg!(T, i))
			InstArgs = AliasSeq!(InstArgs, Parameters!T[i]);
	}
}

/// Function arity (instruction arguments only)
private template InstArity(alias T){
	enum InstArity = InstArgs!T.length;
}

/// ditto
private template InstArities(T...) if (allSatisfy!(isCallable, T)){
	alias InstArities = AliasSeq!();
	static foreach (sym; T)
		InstArities = AliasSeq!(InstArities, InstArity!sym);
}

/// A struct storing an Instruction's InstParams
private template InstArgsStruct(alias T) if (isCallable!T){
	struct InstArgsStruct{
		InstArgs!T params;
	}
}

/// A union containing InstParamStruct for every function
private template InstArgsUnion(T...) if (allSatisfy!(isCallable, T)){
	union InstArgsUnion{
		staticMap!(InstArgsStruct, T) structs;
	}
}

/// If a T can be .sizeof'd
private enum HasSizeof(alias T) = __traits(compiles, T.sizeof);

/// sum of sizes
private template SizeofSum(T...) if (allSatisfy!(HasSizeof, T)){
	static if (T.length == 0){
		enum SizeofSum = 0;
	} else static if (T.length == 1){
		enum SizeofSum = T[0].sizeof;
	} else static if (T.length == 2){
		enum SizeofSum = T[0].sizeof + T[1].sizeof;
	} else {
		enum SizeofSum = T[0].sizeof + SizeofSum!(T[1 .. $]);
	}
}

/// Mapping of Args to Params for an instruction. size_t.max for unmapped
private template InstParamArgMapping(alias T) if (isCallable!T){
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
private template InstCallStatement(alias Inst) if (isCallable!Inst){
	enum InstCallStatement = getStatement();
	private string getStatement(){
		string ret = "sym(";
		static foreach (i, mapTo; InstParamArgMapping!Inst){
			static if (mapTo == size_t.max){
				static if (ParameterIdentifierTuple!Inst[i] == "_ic"){
					ret ~= "ic, ";
				} else static if (ParameterIdentifierTuple!Inst[i] == "_dc"){
					ret ~= "dc, ";
				} else static if (ParameterIdentifierTuple!Inst[i] == "_state"){
					ret ~= "state, ";
				} else static if (is (Parameters!Inst[i] == navm.bytecode.ByteCode)){
					ret ~= "code, ";
				}
			} else {
				ret ~= "pun.structs[ind].params[" ~ mapTo.to!string ~ "], ";
			}
		}
		if (ret[$ - 1] == '(')
			return ret ~ ");";
		return ret[0 .. $ - 2] ~ ");";
	}
}

public void execute(S, T...)(
		ByteCode code,
		S state,
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
