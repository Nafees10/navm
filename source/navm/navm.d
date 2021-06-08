module navm.navm;


import std.conv : to;

import utils.ds;
import utils.misc;

public import navm.bytecode;

/// TODO: move this to utils package
package union ByteUnion(T){
	T data;
	ubyte[T.sizeof] array;
	/// constructor
	this(T data){
		this.data = data;
	}
	/// ditto
	this(ubyte[T.sizeof] array){
		this.array = array;
	}
}

/// Stack, with no fixed data type for elements.
/// 
/// Right now its not used anywhere, but it migth be useful.
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
	b = 0;
	ubyte ub;
	ub = 0;
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
	uinteger _instIndex; /// index of next instruction
	uinteger _argIndex; /// index next argument
	uinteger[] _labelInstIndexes; /// instruction indexes for labels
	uinteger[] _labelArgIndexes; /// argument indexes for labels
	string[] _labelNames; /// label names

	NaInstTable _instTable; /// instruction table

	/// Loads bytecode
	/// 
	/// Returns: array containting errors, or empty array
	string[] _loadBytecode(NaBytecode code){
		if (!code.verify)
			return ["bytecode.verify returned false"];
		_instIndex = 0;
		_argIndex = 0;
		string[] errors;
		_instructions = code.instPtrs;
		foreach (i, inst; _instructions){
			if (inst is null){
				try{
					NaInst instData = _instTable.getInstruction(code.instCodes[i]);
					errors ~= "invalid pointer for instruction `"~instData.name~'`';
				}catch (Exception e){
					.destroy(e);
					errors ~= "invalid instruction code "~code.instCodes[i].to!string;
				}
			}
		}
		// now labels
		_labelNames = code.labelNames;
		_labelInstIndexes.length = _labelNames.length;
		_labelArgIndexes.length = _labelNames.length;
		foreach (i, indexes; code.labelIndexes){
			_labelInstIndexes[i] = indexes[0];
			_labelArgIndexes[i] = indexes[1];
		}
		// append arguments to _args
		foreach (i, ref arg; code.instArgs){
			immutable NaInstArgType type = code.instArgTypes[i];
			if (type == NaInstArgType.String){
				ByteUnion!integer sizeStore;
				string str = arg.value!string;
				sizeStore.data = str.length;
				_args ~= sizeStore.array ~ cast(ubyte[])str;
			}else if (type == NaInstArgType.Boolean || type == NaInstArgType.Char){
				_args ~= arg.value!ubyte;
			}else if (type == NaInstArgType.Double){
				ByteUnion!double valStore;
				valStore.data = arg.value!double;
				_args ~= valStore.array;
			}else if (type == NaInstArgType.Integer || type == NaInstArgType.Label ||
				type == NaInstArgType.Address){
				ByteUnion!integer valStore;
				valStore.data = arg.value!integer;
				_args ~= valStore.array;
			}
		}
		return errors;
	}

	/// Gets an argument. **Do not use this when argument is array (string)**
	T _readArg(T)(){
		immutable T r = *(cast(T*)(_args.ptr + _argIndex*(_argIndex + T.sizeof <= _args.length)));
		_argIndex += T.sizeof;
		return r;
	}
	/// ditto
	T _readArg(T)(uinteger argAddr){
		return *(cast(T*)(_args.ptr + argAddr*(argAddr + T.sizeof <= _args.length)));
	}
	/// Reads an array from arguments. Will try to read enough bytes to fill `array`
	void _readArgArray(T)(T[] array){
		immutable uinteger lenBytes = T.sizeof * array.length;
		immutable uinteger altLenBytes = _args.length - _argIndex;
		if (lenBytes > altLenBytes){
			(cast(ubyte*)array.ptr)[0 .. altLenBytes] = _args[_argIndex .. $];
			_argIndex = _args.length;
			return;
		}
		(cast(ubyte*)array.ptr)[0 .. lenBytes] = _args[_argIndex .. _argIndex + lenBytes];
		_argIndex += lenBytes;
	}
	/// Changes value of an argument. **Do not use this when argument is array (string)**
	/// 
	/// Returns: true if done, false if argument address is out of bounds
	bool _writeArg(T)(uinteger argAddr, T val){
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
	/// instruction table.  
	/// 
	/// **this will be destroyed when this class is destroyed**
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
	/// this function must initialize `_instructions`, `_args`, `_argIndex`,
	/// `_instIndex`, `_labelInstIndexes`, `_labelArgsIndexes`, and `_labelNames`.  
	/// Alternatively, you could use call `_loadBytecode` in this function
	/// 
	/// Returns: [] on success, or errors in case of any
	abstract string[] loadBytecode(NaBytecode code);
	/// starts execution from a label. Will do nothing if label invalid or doesnt exist
	void execute(string labelName){
		integer index = _labelNames.indexOf(labelName);
		if (index > -1)
			execute(index);
	}
	/// ditto
	void execute(uinteger labelIndex){
		if (labelIndex >= _labelInstIndexes.length)
			return;
		_argIndex = _labelArgIndexes[labelIndex];
		_instIndex = _labelInstIndexes[labelIndex];
		while (_instIndex < _instructions.length)
			_instructions[_instIndex++]();
	}
}