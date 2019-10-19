module navm.defs;

import utils.misc;
import utils.lists : ExtraAlloc;
import utils.lists : Stack;

/// to store data from script at runtime
public union RuntimeData{
	integer intVal; /// integer value
	double doubleVal; /// double/float value
	RuntimeData[]* arrayVal; /// array value
	RuntimeData* ptrVal; /// to store references
	/// constructor
	/// data can be any of the type which it can store
	this (T)(T data){
		static if (is (T == int) || is (T == long) || is (T == uint) || is (T == ulong)){
			intVal = data;
		}else static if (is (T == double) || is (T == float)){
			doubleVal = data;
		}else static if (is (T == RuntimeData[]) || is (T == void[])){
			arrayVal = cast(RuntimeData[])data;
		}else static if (is (T == RuntimeData*)){
			ptrVal = data;
		}else{
			throw new Exception("cannot store "~T.stringof~" in RuntimeData");
		}
	}
}

/// Fixed max-length stack (not using utils.lists.Stack because that one isnt optimized to be fast as much as this should be)
///
/// Be aware that no bound checking is done here, so be careful
package class VMStack(T){
private:
	/// the actual stack
	T[] _stackArray;
	/// pointer of the next element that'll be written to next
	T* _peekPtr;
public:
	this(uinteger length=64){
		_stackArray.length = length;
		_peekPtr = _stackArray.ptr;
	}
	/// Reads n number of elements from stack, in reverse order (i.e: [nth-last pushed, (n-1)th-last pushed, ..., last pushed])
	/// 
	/// Returns: the elements read
	T[] pop(uinteger n){
		_peekPtr -= n;
		return _peekPtr[0 .. n];
	}
	/// Reads the last element pushed to stack
	///
	/// Returns: the element pop-ed
	T pop(){
		_peekPtr --;
		return *_peekPtr;
	}
	/// pushes elements to stack. First in array is pushed first
	void push(T[] elements){
		_peekPtr[0 .. elements.length] = elements;
		_peekPtr += elements.length;
	}
	/// pushes an element to stack
	void push(T element){
		*_peekPtr = element;
		_peekPtr ++;
	}
	/// Returns: number of elements present
	@property uinteger count(){
		return cast(uinteger)(_peekPtr - _stackArray.ptr);
	}
	/// Returns: the element at an index (this is possible as the stack is actually an array)
	T read(uinteger index){
		return _stackArray[index];
	}
	/// Writes a value to an index on the stackArray (possible because the stack is actually a stack)
	void write(uinteger index, T value){
		_stackArray[index] = value;
	}
}