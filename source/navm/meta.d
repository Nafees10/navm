module navm.meta;

import std.meta,
			 std.conv,
			 std.traits;

/// Instruction name
public template InstName(alias I) if (isCallable!I){
	enum InstName = __traits(identifier, I);
}

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
	enum InstsIsStateful =
		EraseAll!(false, staticMap!(InstIsStateful, T)).length > 0;
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
	enum SizeofSum = (){
		size_t ret = 0;
		foreach (sym; T)
			ret += sym.sizeof;
		return ret;
	}();
}

/// Mapping of Args to Params for an instruction. size_t.max for unmapped
package template InstParamArgMapping(alias T) if (isCallable!T){
	enum InstParamArgMapping = (){
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
	}();
}

/// Instruction's Parameters alias for calling
package template InstCallStatement(alias Inst) if (isCallable!Inst){
	enum InstCallStatement = (){
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
	}();
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
