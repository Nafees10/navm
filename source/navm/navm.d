module navm.navm;

import navm.defs;
import navm.bytecode;

import std.conv : to;

import utils.lists;
import utils.misc;

public alias NaInstruction = navm.bytecode.NaInst;
public alias readData = navm.bytecode.readData;

/// to store data from script at runtime
public union NaData{
	union{
		bool boolVal; /// boolean value
		dchar dcharVal; /// dchar value
		integer intVal; /// integer value
		double doubleVal; /// double/float value
		NaData* ptrVal; /// to store references
	}
	/// constructor
	/// data can be any of the type which it can store
	this (T)(T data){
		static if (is (T == int) || is (T == long) || is (T == uint) || is (T == ulong)){
			intVal = data;
		}else static if (is (T == double) || is (T == float)){
			doubleVal = data;
		}else static if (is (T == NaData[])){
			arrayVal = data;
		}else static if (is (T == NaData*)){
			ptrVal = data;
		}else static if (is (T == dchar)){
			dcharVal = data;
		}else static if (is (T == dchar[]) || is (T == dstring)){
			strVal = cast(dchar[])data;
		}else static if (is (T == bool)){
			boolVal = data;
		}else{
			throw new Exception("cannot store "~T.stringof~" in NaData");
		}
	}
	/// makes this NaData into an array
	void makeArray(uinteger length){
		NaData[] array;
		array.length = length+1;
		array[0].intVal = length;
		ptrVal = array.ptr+1;
	}
	/// Returns: array value, read from ptrVal
	@property NaData[] arrayVal(){
		return ptrVal[0 .. (*(ptrVal-1)).intVal];
	}
	/// ditto
	@property NaData[] arrayVal(NaData[] newVal){
		NaData[] array = NaData(newVal.length) ~ newVal;
		ptrVal = array.ptr + 1;
		return array[1 .. $];
	}
	/// Returns: array length.
	/// 
	/// Do NOT use this to initialize array, use `makeArray`
	@property uinteger arrayValLength(){
		return (*(ptrVal - 1)).intVal;
	}
	/// ditto
	@property uinteger arrayValLength(uinteger length){
		NaData[] array;
		array.length = length + 1;
		array[0].intVal = length;
		immutable uinteger sliceLength = length > arrayValLength ? arrayValLength : length;
		array[1 .. sliceLength+1] = arrayVal[0 .. sliceLength];
		ptrVal = array.ptr+1;
		return length;
	}
	/// Returns: string value stored as NaData[] (in arrayVal)
	@property dchar[] strVal(){
		dchar[] r;
		r.length = arrayValLength;
		foreach (i, ch; arrayVal){
			r[i] = ch.dcharVal;
		}
		return r;
	}
	/// Setter for strVal
	@property dchar[] strVal(dchar[] newVal){
		makeArray(newVal.length);
		foreach (i, ch; newVal){
			arrayVal[i].dcharVal = ch;
		}
		return newVal;
	}
}

/// the VM
class NaVM{
private:
	/// TODO: instruction table
protected:
	void delegate()[] _instructions; /// instructions of loaded byte code
	NaData[] _arguments; /// argument of each instruction
	void delegate()* _inst; /// pointer to next instruction
	NaData* _arg; /// pointer to next instruction's arguments

public:
	/// constructor
	this(uinteger stackLength = 65_536){
	}
	/// destructor
	~this(){
	}
}