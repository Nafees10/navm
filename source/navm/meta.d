module navm.meta;

import std.meta : AliasSeq, allSatisfy, anySatisfy;
import std.traits : isCallable, Parameters, ParameterIdentifierTuple,
			 isArray, hasUDA;

import navm.common : intToStr;

/// Explicit Instruction name
public struct Inst{
	string name;
	@disable this();
	this(string name){
		this.name = name;
	}
}

/// Instruction name
package template InstName(alias I) if (isCallable!I){
	static if (hasUDA!(I, Inst)){
		enum InstName = getUDAs!(I, Inst)[0].name;
	} else {
		enum InstName = __traits(identifier, I);
	}
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
package enum InstsIsStateful(T...) = anySatisfy!(InstIsStateful, T);

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

/// If a T can be .sizeof'd
package enum HasSizeof(alias T) = __traits(compiles, T.sizeof) ||
	is (T == string);

/// sum of sizes
package template SizeofSum(T...) if (allSatisfy!(HasSizeof, T)){
	enum SizeofSum = (){
		size_t ret = 0;
		foreach (sym; T){
			static if (isArray!sym){
				ret += size_t.sizeof;
			} else {
				ret += sym.sizeof;
			}
		}
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
				ret ~= "p[" ~ mapTo.intToStr ~ "], ";
			}
		}
		if (ret[$ - 1] == '(')
			return ret ~ ");";
		return ret[0 .. $ - 2] ~ ");";
	}();
}
