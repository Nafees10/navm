module navm.defs;

import utils.misc;

/// to store data from script at runtime
public union NaData{
	union{
		bool boolVal; /// boolean value
		dchar dcharVal; /// dchar value
		integer intVal; /// integer value
		double doubleVal; /// double/float value
		NaData* ptrVal; /// to store references
		NaData[] arrayVal; /// array value
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
			strVal = data;
		}else static if (is (T == bool)){
			boolVal = data;
		}else{
			throw new Exception("cannot store "~T.stringof~" in NaData");
		}
	}
	/// Returns: string value stored as NaData[] (in arrayVal)
	@property dchar[] strVal(){
		dchar[] r;
		r.length = arrayVal.length;
		foreach (i, ch; arrayVal){
			r[i] = ch.dcharVal;
		}
		return r;
	}
	/// Setter for strVal
	@property dchar[] strVal(dchar[] newVal){
		arrayVal.length = newVal.length;
		foreach (i, ch; newVal){
			arrayVal[i].dcharVal = ch;
		}
		return newVal;
	}
	/// Setter for strVal
	@property char[] strVal(dstring newVal){
		arrayVal.length = newVal.length;
		foreach (i, ch; newVal){
			arrayVal[i].intVal = cast(integer)ch;
		}
		return cast(char[])newVal;
	}
}

/// for storing a stack frame in stack
struct StackFrame{
	void delegate()* instruction; /// instruction
	NaData* argument; /// argument for that instruction
}

/// a simple array based stack
/// 
/// no bound checking is done, so be careful
public class ArrayStack(T){
private:
	T[] _array;
	T* _peekPtr;
public:
	/// constructor (set the stack length here)
	this(uinteger length=65_536){
		_array.length = length;
		_peekPtr = _array.ptr;
	}
	/// Pops an element from stack
	/// 
	/// Returns: popped element
	T pop(){
		_peekPtr --;
		return *_peekPtr;
	}
	/// pushes an element to stack
	void push(T element){
		*_peekPtr = element;
		_peekPtr++;
	}
	/// number of elements in stack
	@property uinteger count(){
		return cast(uinteger)(_peekPtr - _array.ptr);
	}
	/// Reads n number of elements from stack, in reverse order (i.e: [nth-last pushed, (n-1)th-last pushed, ..., last pushed])
	/// 
	/// Returns: the elements read
	T[] pop(uinteger n){
		_peekPtr -= n;
		return _peekPtr[0 .. n];
	}
	/// pushes elements to stack. First in array is pushed first
	void push(T[] elements){
		_peekPtr[0 .. elements.length] = elements;
		_peekPtr += elements.length;
	}
	/// Returns: element at currentIndex-index
	T readRelative(uinteger index){
		return *(_peekPtr - index);
	}
	/// Returns: pointer to element at currentIndex-index;
	T* readPtrRelative(uinteger index){
		return _peekPtr - index;
	}
	/// Writes a value to `currentIndex-index`
	void writeRelative(uinteger index, T value){
		*(_peekPtr - index) = value;
	}
}