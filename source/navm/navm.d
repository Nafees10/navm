module navm.navm;

import std.conv,
			 std.meta,
			 std.traits;

public import navm.bytecode;

interface Shared{}

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

/// Function arity (instruction arguments only)
private template InstArity(alias T) if (isCallable!T){
	enum InstArity = getArity();
	private size_t getArity(){
		size_t sub = 0;
		foreach (i, pT; Parameters!T){
			if (is (pT : navm.navm.Shared) ||
					is (pT == navm.bytecode.ByteCode) || (
						is (pT == size_t*) && (
							ParameterIdentifierTuple!T[i] == "_ic" ||
							ParameterIdentifierTuple!T[i] == "_dc")))
				sub ++;
		}
		return arity!T - sub;
	}
}

/// ditto
private template InstArities(T...) if (allSatisfy!(isCallable, T)){
	alias InstArities = AliasSeq!();
	static foreach (sym; T)
		InstArities = AliasSeq!(InstArities, InstArity!sym);
}

/// Number of parameters of function T that are of a type TT
private template ParamTypeCount(T, TT) if (isCallable!T){
	enum ParamTypeCount = getTypeCount();
	private size_t getTypeCount(){
		size_t ret = 0;
		foreach (sym; Parameters!T){
			if (is(sym == TT))
				ret ++;
		}
		return ret;
	}
}

/// sum of sizes
private template SizeofSum(T...) if (__traits(compiles, T[0].sizeof)){
	enum SizeofSum = getSizeofSum();
	private size_t getSizeofSum(){
		size_t ret = 0;
		foreach (sym; T)
			ret += sym.sizeof;
		return ret;
	}
}

public void execute(T...)(
		ByteCode code,
		Shared obj = null,
		string label = null)
	if (
		allSatisfy!(isCallable, T)){
	size_t ic, dc;
	if (label != null){
		ic = code.labels[label][0];
		dc = code.labels[label][1];
	}
	const len = code.instructions.length;
	while (ic < len){
		switcher: switch (code.instructions[ic]){
			foreach (ind, sym; T){
				case ind:
					Parameters!sym params;
					static foreach (i; 0 .. params.length){
						static if (is (typeof(params[i]) : Shared)){
							params[i] = cast(typeof(params[i]))obj;
						} else static if (is (typeof(params[i]) == ByteCode)){
							params[i] = code;
						} else static if (is (typeof(params[i]) == size_t*) &&
								ParameterIdentifierTuple!sym[i] == "_ic"){
							params[i] = &ic;
						} else static if (is (typeof(params[i]) == size_t*) &&
								ParameterIdentifierTuple!sym[i] == "_dc"){
							params[i] = &dc;
						} else {
							params[i] = code.data[dc].value!(typeof(params[i]));
						}
					}
					ic ++;
					dc += InstArity!sym;
					sym(params);
					import std.stdio;writeln(ic);
					break switcher;
			}
			default:
				break;
		}
	}
}
