module navm.navm;

import navm.defs;
import navm.bytecode;

import std.conv : to;

import utils.lists;
import utils.misc;

public alias NaData = navm.defs.NaData;
public alias NaInstruction = navm.bytecode.NaInstruction;
public alias readData = navm.bytecode.readData;

/// the VM
class NaVM{
private:
	NaInstruction[] _instructionTable; /// what instructions are what
protected:
	void delegate()[] _instructions; /// instructions of loaded byte code
	NaData[] _arguments; /// argument of each instruction
	void delegate()* _inst; /// pointer to next instruction
	NaData* _arg; /// pointer to next instruction's arguments
	uinteger _stackIndex; /// stack index relative to which some instructions will pushFrom/writeTo
	ArrayStack!NaData _stack; /// as the name says, stack
	ArrayStack!StackFrame _jumpStack; /// for storing pointers before jumping
	// instructions:

	void mathAddInt(){
		_stack.push(
			NaData(_stack.pop.intVal + _stack.pop.intVal)
			);
	}
	void mathSubtractInt(){
		_stack.push(
			NaData(_stack.pop.intVal - _stack.pop.intVal)
			);
	}
	void mathMultiplyInt(){
		_stack.push(
			NaData(_stack.pop.intVal * _stack.pop.intVal)
			);
	}
	void mathDivideInt(){
		_stack.push(
			NaData(_stack.pop.intVal / _stack.pop.intVal)
			);
	}
	void mathModInt(){
		_stack.push(
			NaData(_stack.pop.intVal % _stack.pop.intVal)
			);
	}

	void mathAddDouble(){
		_stack.push(
			NaData(_stack.pop.doubleVal + _stack.pop.doubleVal)
			);
	}
	void mathSubtractDouble(){
		_stack.push(
			NaData(_stack.pop.doubleVal - _stack.pop.doubleVal)
			);
	}
	void mathMultiplyDouble(){
		_stack.push(
			NaData(_stack.pop.doubleVal * _stack.pop.doubleVal)
			);
	}
	void mathDivideDouble(){
		_stack.push(
			NaData(_stack.pop.doubleVal / _stack.pop.doubleVal)
			);
	}
	void mathModDouble(){
		_stack.push(
			NaData(_stack.pop.doubleVal % _stack.pop.doubleVal)
			);
	}

	void isSame(){
		_stack.push(NaData(_stack.pop.intVal == _stack.pop.intVal));
	}
	void isGreaterInt(){
		_stack.push(NaData(_stack.pop.intVal > _stack.pop.intVal));
	}
	void isGreaterSameInt(){
		_stack.push(NaData(_stack.pop.intVal >= _stack.pop.intVal));
	}
	void isLesserInt(){
		_stack.push(NaData(_stack.pop.intVal < _stack.pop.intVal));
	}
	void isLesserSameInt(){
		_stack.push(NaData(_stack.pop.intVal <= _stack.pop.intVal));
	}

	void isGreaterDouble(){
		_stack.push(NaData(_stack.pop.doubleVal > _stack.pop.doubleVal));
	}
	void isGreaterSameDouble(){
		_stack.push(NaData(_stack.pop.doubleVal >= _stack.pop.doubleVal));
	}
	void isLesserDouble(){
		_stack.push(NaData(_stack.pop.doubleVal < _stack.pop.doubleVal));
	}
	void isLesserSameDouble(){
		_stack.push(NaData(_stack.pop.doubleVal <= _stack.pop.doubleVal));
	}

	void binaryNot(){
		_stack.push(NaData(!_stack.pop.boolVal));
	}
	void binaryAnd(){
		_stack.push(NaData(_stack.pop.boolVal && _stack.pop.boolVal));
	}
	void binaryOr(){
		_stack.push(NaData(_stack.pop.boolVal || _stack.pop.boolVal));
	}

	void push(){
		_stack.push(*_arg);
	}
	void pushFromAbs(){
		_stack.push(_stack.read(_arg.intVal));
	}
	void pushRefFromAbs(){
		_stack.push(NaData(_stack.readPtr(_arg.intVal)));
	}
	void writeToAbs(){
		_stack.write(_arg.intVal,_stack.pop);
	}
	void pushFrom(){
		_stack.push(_stack.read(_arg.intVal + _stackIndex));
	}
	void pushRefFrom(){
		_stack.push(NaData(_stack.readPtr(_arg.intVal + _stackIndex)));
	}
	void writeTo(){
		_stack.write(_arg.intVal + _stackIndex, _stack.pop);
	}
	void pop(){
		_stack.pop;
	}
	void popN(){
		_stack.pop(_arg.intVal);
	}

	void writeToRef(){
		// Left side is evaluated first
		*(_stack.pop.ptrVal) = _stack.pop;
	}
	void deref(){
		_stack.push(*(_stack.pop.ptrVal));
	}
	void incRef(){
		_stack.push(NaData(_stack.pop.ptrVal + _stack.pop.intVal));
	}

	void doIf(){
		if (_stack.pop.boolVal == false){
			_inst++;
			_arg++;
		}
	}
	void jump(){
		_inst = (_instructions.ptr + _arg.intVal) -1;
		_arg = (_arguments.ptr + _arg.intVal) -1;
	}
	void jumpFrame(){
		_jumpStack.push(StackFrame(_inst, _arg, _stackIndex));
		_inst = (_instructions.ptr + _arg.intVal) -1;
		_arg = (_arguments.ptr + _arg.intVal) -1;
		_stackIndex = _stack.count;
	}
	void jumpBack(){
		if (_jumpStack.count){
			StackFrame frame = _jumpStack.pop;
			_inst = frame.instruction;
			_arg = frame.argument;
			_stack.peek(_stackIndex);
			_stackIndex = frame.stackIndex;
			return;
		}
		_inst = &(_instructions)[$-1] + 1;
	}

	void makeArray(){
		NaData array;
		array.makeArray(_stack.pop.intVal);
		_stack.push(array);
	}
	void arrayLength(){
		_stack.push(NaData(_stack.pop.arrayValLength));
	}
	void arrayLengthSet(){
		NaData array = _stack.pop;
		array.arrayValLength = _stack.pop.intVal;
		_stack.push(array);
	}
	void isSameArray(){
		NaData[] a = _stack.pop.arrayVal, b = _stack.pop.arrayVal;
		if (a.length != b.length){
			_stack.push(NaData(false));
			return;
		}
		NaData* aPtr = a.ptr, bPtr = b.ptr, aEnd = aPtr + a.length;
		for (; aPtr < aEnd; ){
			if (aPtr.intVal != bPtr.intVal){
				_stack.push(NaData(false));
				return;
			}
			aPtr ++;
			bPtr ++;
		}
		_stack.push(NaData(true));
	}

	void intToDouble(){
		_stack.push(NaData(to!double(_stack.pop.intVal)));
	}
	void intToString(){
		_stack.push(NaData(to!dstring(_stack.pop.intVal)));
	}
	void boolToString(){
		_stack.push(NaData((_stack.pop.boolVal).to!dstring));
	}
	void stringToBool(){
		_stack.push(NaData(_stack.pop.strVal == "true" ? true : false));
	}
	void doubleToInt(){
		_stack.push(NaData(to!integer(_stack.pop.doubleVal)));
	}
	void doubleToString(){
		_stack.push(NaData(to!dstring(_stack.pop.doubleVal)));
	}
	void stringToInt(){
		_stack.push(NaData(to!integer(_stack.pop.strVal)));
	}
	void stringToDouble(){
		_stack.push(NaData(to!double(_stack.pop.strVal)));
	}
public:
	/// constructor
	this(uinteger stackLength = 65_536){
		// prepare instruction table, forget codes, will do them in a loop after
		_instructionTable = [
			NaInstruction("mathAddInt",0,2,1,&mathAddInt),
			NaInstruction("mathSubtractInt",0,2,1,&mathSubtractInt),
			NaInstruction("mathMultiplyInt",0,2,1,&mathMultiplyInt),
			NaInstruction("mathDivideInt",0,2,1,&mathDivideInt),
			NaInstruction("mathModInt",0,2,1,&mathModInt),
			NaInstruction("mathAddDouble",0,2,1,&mathAddDouble),
			NaInstruction("mathSubtractDouble",0,2,1,&mathSubtractDouble),
			NaInstruction("mathMultiplyDouble",0,2,1,&mathMultiplyDouble),
			NaInstruction("mathDivideDouble",0,2,1,&mathDivideDouble),
			NaInstruction("mathModDouble",0,2,1,&mathModDouble),
			NaInstruction("isSame",0,2,1,&isSame),
			NaInstruction("isGreaterInt",0,2,1,&isGreaterInt),
			NaInstruction("isGreaterSameInt",0,2,1,&isGreaterSameInt),
			NaInstruction("isLesserInt",0,2,1,&isLesserInt),
			NaInstruction("isLesserSameInt",0,2,1,&isLesserSameInt),
			NaInstruction("isGreaterDouble",0,2,1,&isGreaterDouble),
			NaInstruction("isGreaterSameDouble",0,2,1,&isGreaterSameDouble),
			NaInstruction("isLesserDouble",0,2,1,&isLesserDouble),
			NaInstruction("isLesserSameDouble",0,2,1,&isLesserSameDouble),
			NaInstruction("not",0,1,1,&binaryNot),
			NaInstruction("and",0,2,1,&binaryAnd),
			NaInstruction("or",0,2,1,&binaryOr),
			NaInstruction("push",0,true,0,1,&push),
			NaInstruction("pushFrom",0,true,0,1,&pushFrom),
			NaInstruction("pushRefFrom",0,true,0,1,&pushRefFrom),
			NaInstruction("writeTo",0,true,1,0,&writeTo),
			NaInstruction("pushFromAbs",0,true,0,1,&pushFromAbs),
			NaInstruction("pushRefFromAbs",0,true,0,1,&pushRefFromAbs),
			NaInstruction("writeToAbs",0,true,1,0,&writeToAbs),
			NaInstruction("pop",0,1,0,&pop),
			NaInstruction("popN",0,true,255,0,&popN),
			NaInstruction("writeToRef",0,2,0,&writeToRef),
			NaInstruction("deref",0,1,1,&deref),
			NaInstruction("incRef",0,2,1,&incRef),
			NaInstruction("if",0,1,0,&doIf),
			NaInstruction("jump",0,true,true,0,0,&jump),
			NaInstruction("jumpFrame",0,true,true,0,0,&jumpFrame),
			NaInstruction("jumpBack",0,&jumpBack),
			NaInstruction("makeArray",0,1,1,&makeArray),
			NaInstruction("arrayLength",0,1,1,&arrayLength),
			NaInstruction("arrayLengthSet",0,2,1,&arrayLengthSet),
			NaInstruction("isSameArray",0,2,1,&isSameArray),
			NaInstruction("intToDouble",0,1,1,&intToDouble),
			NaInstruction("intToString",0,1,1,&intToString),
			NaInstruction("boolToString",0,1,1,&boolToString),
			NaInstruction("stringToBool",0,1,1,&stringToBool),
			NaInstruction("doubleToInt",0,1,1,&doubleToInt),
			NaInstruction("doubleToString",0,1,1,&doubleToString),
			NaInstruction("stringToInt",0,1,1,&stringToInt),
			NaInstruction("stringToDouble",0,1,1,&stringToDouble),
		];
		// now assign codes
		foreach (i; 0 .. _instructionTable.length)
			_instructionTable[i].code = cast(ushort)i;
		// prepare stack
		_stack = new ArrayStack!NaData(stackLength);
		_jumpStack = new ArrayStack!StackFrame;
	}
	/// destructor
	~this(){
		.destroy(_stack);
		.destroy(_jumpStack);
	}
	/// Loads bytecode into VM
	/// 
	/// Returns: errors in a string[], or [] if no errors
	string[] load(string[] byteCode){
		NaBytecode bcode = new NaBytecode(_instructionTable.dup);
		string[] r = bcode.readByteCode(byteCode);
		if (r.length)
			return r;
		r = bcode.resolve();
		if (r.length)
			return r;
		_instructions = bcode.getBytecodePointers();
		try{
			_arguments = bcode.getArgumentsNaData();
		}catch (Exception e){
			string msg = e.msg;
			.destroy(e);
			return [msg];
		}
		return [];
	}
	/// ditto
	string[] load(NaBytecode byteCode){
		string[] r = byteCode.resolve();
		if (r.length)
			return r;
		_instructions = byteCode.getBytecodePointers();
		try{
			_arguments = byteCode.getArgumentsNaData();
		}catch (Exception e){
			string msg = e.msg;
			.destroy(e);
			return [msg];
		}
		return [];
	}
	/// a copy of the instructions table
	@property NaInstruction[] instructionTable(){
		return _instructionTable.dup;
	}
	/// Adds a new instruction
	/// 
	/// Returns: true on success, false if not (pointer might be null, code might be already in use, name might already be in use)
	bool addInstruction(NaInstruction instruction, ref string error){
		if (instruction.pointer is null){
			error = "instruction pointer cannot be null";
			return false;
		}
		instruction.name = instruction.name.lowercase();
		foreach (inst; _instructionTable){
			if (instruction.name == inst.name){
				error = "instruction name, "~inst.name~", already exists";
				return false;
			}
			if (instruction.code == inst.code){
				error = "instruction code, "~inst.code.to!string~", already exists";
				return false;
			}
		}
		_instructionTable ~= instruction;
		return true;
	}
	/// ditto
	bool addInstruction(NaInstruction instruction){
		string error;
		return addInstruction(instruction, error);
	}
	/// Clears stack
	void clearStack(){
		if (_stack.count)
			_stack.pop(_stack.count);
	}
	/// Starts execution of byte code, starting with the instruction at `index`
	void execute(uinteger index = 0){
		if (index >= _instructions.length)
			return;
		_inst = &(_instructions[index]);
		_arg = &(_arguments[index]);
		const void delegate()* lastInst = &_instructions[$-1]+1;
		do{
			(*_inst)();
			_inst++;
			_arg++;
		}while (_inst < lastInst);
	}
}