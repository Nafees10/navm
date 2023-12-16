module navm.navm;

import std.conv,
			 std.traits;

import utils.ds;
import utils.misc;

public import navm.bytecode;

/// NaVM abstract class
public abstract class NaVM{
protected:
	void delegate()[] _instructions; /// the instruction pointers
	ubyte[] _args; /// stores arguments
	size_t _instIndex; /// index of next instruction
	size_t _argIndex; /// index next argument
	size_t[] _labelInstIndexes; /// instruction indexes for labels
	size_t[] _labelArgIndexes; /// argument indexes for labels
	string[] _labelNames; /// label names

	NaInstTable _instTable; /// instruction table

	/// Gets an argument. **Do not use this when argument is array (string)**
	T _readArg(T)(){
		immutable T r = *(cast(T*)(_args.ptr + _argIndex*(_argIndex + T.sizeof <= _args.length)));
		_argIndex += T.sizeof;
		return r;
	}
	/// ditto
	T _readArg(T)(size_t argAddr){
		return *(cast(T*)(_args.ptr + argAddr*(argAddr + T.sizeof <= _args.length)));
	}
	/// Reads an array from arguments. Will try to read enough bytes to fill `array`
	void _readArgArray(T)(T[] array){
		immutable size_t lenBytes = T.sizeof * array.length;
		immutable size_t altLenBytes = _args.length - _argIndex;
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
	bool _writeArg(T)(size_t argAddr, T val){
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
	///
	/// Returns: [] on success, or errors in case of any
	string[] loadBytecode(NaBytecode code){
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
				ByteUnion!ptrdiff_t sizeStore;
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
				ByteUnion!ptrdiff_t valStore;
				valStore.data = arg.value!ptrdiff_t;
				_args ~= valStore.array;
			}
		}
		return errors;
	}
	/// starts execution from a label. Will do nothing if label invalid or doesnt exist
	void execute(string labelName){
		ptrdiff_t index = _labelNames.indexOf(labelName);
		if (index > -1)
			execute(index);
	}
	/// ditto
	void execute(size_t labelIndex){
		if (labelIndex >= _labelInstIndexes.length)
			return;
		_argIndex = _labelArgIndexes[labelIndex];
		_instIndex = _labelInstIndexes[labelIndex];
		while (_instIndex < _instructions.length)
			_instructions[_instIndex++]();
	}
}
