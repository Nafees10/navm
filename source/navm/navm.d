module navm.navm;


import std.conv : to;

import utils.ds;
import utils.misc;

public import navm.bytecode;

/// Stack, with no fixed data type for elements.
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

/// NaVM abstract class
public abstract class NaVM{
protected:
	void delegate()[] _instructions; /// the instruction pointers
	ubyte[] _args; /// stores arguments
	void delegate()* _instPtr; /// pointer to next instruction
	void delegate()* _instLastPtr; /// pointer to last instruction
	ubyte* _argPtr; /// pointer to next argument
	ubyte* _argLastPtr; /// pointer to last argument
	void delegate()*[] _labelInstPtr; /// instruction pointer for labels
	ubyte*[] _labelArgsPtr; /// argument pointer for labels
	string[] _labelNames; /// label names

	NaInstTable _instTable; /// instruction table

	/// Loads bytecode
	/// 
	/// set `invalidLabelToString` if you want invalid label arguments to be read as strings
	/// 
	/// Returns: array containting errors, or empty array
	string[] _loadBytecode(NaBytecode code, bool invalidLabelToString){
		// TODO
		return [];
	}

	/// Gets an argument.
	/// 
	/// Returns: the argument, or T.init if no more arguments
	T _getArg(T)(){
		if (_argPtr + T.sizeof > _argLastPtr)
			return T.init;
		T r = *(cast(T*)_argPtr);
		_argPtr += T.sizeof;
		return r;
	}
	/// Changes value of an argument.
	/// 
	/// Returns: true if done, false if argument address is out of bounds
	bool _setArg(T)(uinteger argAddr, T val){
		if (argAddr + T.sizeof > _args.length)
			return false;
		*cast(T*)(_args.ptr + argAddr) = val;
		return true;
	}
public:
	/// constructor
	this(){
		_instTable = new NaInstTable();
	}
	~this(){
		.destroy(_instTable);
	}
	/// instruction table
	@property NaInstTable instTable(){
		return _instTable;
	}
	/// label names, at corresponding label index
	@property string[] labelNames(){
		return _labelNames;
	}
	/// loads bytecode
	/// 
	/// Overriding:  
	/// this function must initialize `_instructions`, `_args`, `_argPtr`,
	/// `_argLastPtr`, `_instPtr`, `_instLastPtr`, `_labelInstPtr`,
	/// `_labelArgsPtr`, and `_labelNames`.  
	/// Alternatively, you could use call `_loadBytecode` in this function
	/// 
	/// Returns: [] on success, or errors in case of any
	abstract string[] loadBytecode(NaBytecode code);
	/// starts execution from a label.
	void execute(string labelName){
		integer index = _labelNames.indexOf(labelName);
		if (index > -1)
			execute(index);
	}
	/// ditto
	void execute(uinteger labelIndex){
		if (labelIndex >= _labelArgsPtr.length)
			return;
		_argPtr = _labelArgsPtr[labelIndex];
		_instPtr = _labelInstPtr[labelIndex];
		while (_instPtr)
			(*_instPtr)();
	}
}