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
		_ptr = _stack.ptr;
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
		_ptr[0 .. T.sizeof] = (cast(ubyte*)&element)[0 .. T.sizeof];
		_ptr += T.sizeof;
	}
	/// pushes multiple elements to stack. last in array is first pushed
	/// 
	/// Either all are pushed, or none if there isn't enough space
	void pushArray(T)(T[] elements){
		immutable uinteger lenBytes = T.sizeof * elements.length;
		if (_ptr + lenBytes > _lastPtr){
			_errored = true;
			return;
		}
		_ptr[0 .. lenBytes] = (cast(ubyte*)elements.ptr)[0 .. lenBytes];
		_ptr += lenBytes;
	}
	/// pops from stack
	/// 
	/// Sets `val` to popped value
	void pop(T)(ref T val){
		if (_ptr < _stack.ptr + T.sizeof){
			_errored = true;
			return;
		}
		_ptr -= T.sizeof;
		val = *(cast(T*)_ptr);
	}
	/// pops multiple from stack. first popped is last in array
	/// 
	/// Writes popped values to `vals`. If there arent enough elements on stack, will not pop anything
	void popArray(T)(ref T[] vals){
		immutable uinteger lenBytes = T.sizeof * vals.length;
		if (_ptr < _stack.ptr + lenBytes){
			_errored = true;
			return;
		}
		_ptr -= lenBytes;
		vals[0 .. vals.length] = (cast(T*)_ptr)[0 .. vals.length];
	}
}
/// 
unittest{
	NaStack s = new NaStack();
	s.push!integer(integer.max);
	s.push!ubyte(255);
	s.push!byte(127);
	byte b;
	ubyte ub;
	integer[] iA = [0];
	assert(s.errored == false);
	s.pop(b);
	s.pop(ub);
	s.pop(iA[0]);
	assert(b == 127);
	assert(ub == 255);
	assert(iA[0] == integer.max);
	iA = [integer.max, integer.max >> 1, 0, 1025];
	s.pushArray(iA);
	iA[] = 0;
	s.popArray(iA);
	assert(iA == [integer.max, integer.max >> 1, 0, 1025]);
	s.push(cast(integer)integer.max);
	s.push(cast(integer)integer.max >> 1);
	s.push(cast(integer)0);
	s.push(cast(integer)1025);
	iA[] = 0;
	s.popArray(iA);
	assert(iA == [integer.max, integer.max >> 1, 0, 1025]);
	assert(s.errored == false);
	.destroy(s);
}

/// NaVM
public class NaVM{
protected:
	void delegate()[] _instructions; /// the instruction pointers
	ubyte[] _args; /// stores arguments
}