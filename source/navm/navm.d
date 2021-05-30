module navm.navm;


import std.conv : to;

import utils.ds;
import utils.misc;

public import navm.bytecode;

/// a stack
public class NaStack{
private:
	ubyte[] _stack;
	ubyte* _ptr;
	ubyte* _lastPtr;
	bool _errored; // if error occurred since last checked
public:
	/// constructor
	/// size is the size in bytes, default is 64 KiB
	this(uinteger size = 1 << 16){
		_stack.length = size;
		_lastPtr = _stack.ptr + size;
	}
	~this(){
		.destroy(_stack);
	}
	/// if an error has occured, since this was last called
	@property bool errored(){
		immutable bool r = _errored;
		_errored = false;
		return r;
	}
	/// seek index (number of bytes used on stack)
	@property uinteger seek(){
		return _ptr - _stack.ptr;
	}
	/// empty stack, sets all bytes to zero, resets seek
	void clear(){
		_stack[] = 0;
		_ptr = _stack.ptr;
		_errored = false;
	}
	/// pushes to stack
	void push(T)(T element){
		if (_ptr + T.sizeof > _lastPtr){
			_errored = true;
			return;
		}
		_ptr[0 .. T.sizeof] = element;
		_ptr += T.sizeof;
	}
	/// pushes multiple elements to stack. last in array is first pushed
	/// 
	/// Either all are pushed, or none if there isn't enough space
	void push(T)(T[] elements){
		immutable static uinteger lenBytes = T.sizeof * elements.length;
		if (_ptr + lenBytes > _lastPtr){
			_errored = true;
			return;
		}
		_ptr[0 .. lenBytes] = (cast(ubyte*)elements.ptr)[0 .. lenBytes];
	}
	/// pops from stack
	/// 
	/// Sets `val` to popped value
	void pop(T)(ref T val){
		immutable static uinteger lenBytes = T.sizeof;
		if (_ptr < _stack.ptr + lenBytes){
			_errored = true;
			return;
		}
		_ptr -= lenBytes;
		val = *(cast(T*)_ptr);
	}
	/// pops multiple from stack. first popped is last in array
	/// 
	/// Writes popped values to `vals`. If there arent enough elements on stack, will not pop anything
	void pop(T)(ref T[] vals){
		immutable static uinteger lenBytes = T.sizeof * vals.length;
		if (_ptr < _stack.ptr + lenBytes){
			_errored = true;
			return;
		}
		_ptr -= lenBytes;
		vals = (cast(T*)_ptr)[0 .. vals.length];
	}
}

/// NaVM
public class NaVM{
protected:
	void delegate()[] _instructions; /// the instruction pointers
	ubyte[] _args; /// stores arguments
}