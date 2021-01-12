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
	void isSameArray(){
		NaData[] a = _stack.pop.arrayVal, b = _stack.pop.arrayVal;
		NaData r = NaData(false);
		if (a.length == b.length){
			r = NaData(true);
			NaData* aPtr = &a[0], bPtr = &b[0];
			for (uinteger i = 0; i < a.length; i++){
				if ((*aPtr).intVal != (*bPtr).intVal){
					r = NaData(false);
					break;
				}
				aPtr ++;
				bPtr ++;
			}
		}
		_stack.push(r);
	}
	void isSameArrayRef(){
		NaData[] a = _stack.pop.ptrVal.arrayVal, b = _stack.pop.ptrVal.arrayVal;
		NaData r = NaData(false);
		if (a.length == b.length){
			r = NaData(true);
			NaData* aPtr = &a[0], bPtr = &b[0];
			for (uinteger i = 0; i < a.length; i++){
				if ((*aPtr).intVal != (*bPtr).intVal){
					r = NaData(false);
					break;
				}
				aPtr ++;
				bPtr ++;
			}
		}
		_stack.push(r);
	}

	void isGreaterInt(){
		_stack.push(NaData(_stack.pop.intVal > _stack.pop.intVal));
	}
	void isGreaterSameInt(){
		_stack.push(NaData(_stack.pop.intVal >= _stack.pop.intVal));
	}

	void isGreaterDouble(){
		_stack.push(NaData(_stack.pop.doubleVal > _stack.pop.doubleVal));
	}
	void isGreaterSameDouble(){
		_stack.push(NaData(_stack.pop.doubleVal >= _stack.pop.doubleVal));
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
	void pushFrom(){
		_stack.push(_stack.readRelative(_arg.intVal));
	}
	void pushRefFrom(){
		_stack.push(NaData(_stack.readPtrRelative(_arg.intVal)));
	}
	void writeTo(){
		_stack.writeRelative(_arg.intVal,_stack.pop);
	}
	void writeToRef(){
		// Left side is evaluated first
		*(_stack.pop.ptrVal) = _stack.pop;
	}
	void deref(){
		_stack.push(*(_stack.pop.ptrVal));
	}
	void pop(){
		_stack.pop;
	}
	void popN(){
		_stack.pop(_arg.intVal);
	}
	void jump(){
		_inst = &(_instructions)[_arg.intVal] - 1;
		_arg = &(_arguments)[_arg.intVal] - 1;
	}
	void jumpIf(){
		if (_stack.pop.boolVal == true){
			_inst = &(_instructions)[_arg.intVal] - 1;
			_arg = &(_arguments)[_arg.intVal] - 1;
		}
	}
	void jumpStack(){
		_jumpStack.push(StackFrame(_inst, _arg));
		_inst = &(_instructions)[_arg.intVal] - 1;
		_arg = &(_arguments)[_arg.intVal] - 1;
	}
	void jumpBack(){
		StackFrame frame;
		if (_jumpStack.count){
			frame = _jumpStack.pop;
			_inst = frame.instruction;
			_arg = frame.argument;
			return;
		}
		_inst = &(_instructions)[$-1] + 1;
	}

	void makeArray(){
		_stack.push(NaData(_stack.pop(_arg.intVal).dup));
	}
	void arrayRefElement(){
		NaData arrayRef = _stack.pop;
		_stack.push(NaData(&((*(arrayRef.ptrVal)).arrayVal[_stack.pop.intVal])));
	}
	void arrayElement(){
		NaData array = _stack.pop;
		_stack.push(NaData(&(array.arrayVal[_stack.pop.intVal])));
	}
	void arrayLength(){
		_stack.push(NaData(_stack.pop.arrayVal.length));
	}
	void arrayLengthSet(){
		/// Left side evaluated first
		(*(_stack.pop.ptrVal)).arrayVal.length = _stack.pop.intVal;
	}
	void concatenate(){
		_stack.push(NaData((_stack.pop.arrayVal ~ _stack.pop.arrayVal).dup));
	}
	void appendElement(){
		/// ~= evaluates right side first unfortunately, so no one liner :(
		NaData arrayPtr = _stack.pop;
		arrayPtr.ptrVal.arrayVal ~= _stack.pop;
	}
	void appendArrayRef(){
		/// ~= evaluates right side first unfortunately, so no one liner :(
		NaData arrayPtr = _stack.pop;
		arrayPtr.ptrVal.arrayVal ~= (*(_stack.pop.ptrVal)).arrayVal;
	}
	void appendArray(){
		/// ~= evaluates right side first unfortunately
		NaData arrayPtr = _stack.pop;
		arrayPtr.ptrVal.arrayVal ~= _stack.pop.arrayVal;
	}
	void copyArray(){
		_stack.push(NaData(_stack.pop.arrayVal.dup));
	}
	void copyArrayRef(){
		_stack.push(NaData((*(_stack.pop.ptrVal)).arrayVal.dup));
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

	void terminate(){
		_inst = &(_instructions)[$-1] + 1;
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
			NaInstruction("isSameArray",0,2,1,&isSameArray),
			NaInstruction("isSameArrayRef",0,2,1,&isSameArrayRef),
			NaInstruction("isGreaterInt",0,2,1,&isGreaterInt),
			NaInstruction("isGreaterSameInt",0,2,1,&isGreaterSameInt),
			NaInstruction("isGreaterDouble",0,2,1,&isGreaterDouble),
			NaInstruction("isGreaterSameDouble",0,2,1,&isGreaterSameDouble),
			NaInstruction("not",0,1,1,&binaryNot),
			NaInstruction("and",0,2,1,&binaryAnd),
			NaInstruction("or",0,2,1,&binaryOr),
			NaInstruction("push",0,true,0,1,&push),
			NaInstruction("pushFrom",0,true,0,1,&pushFrom),
			NaInstruction("pushRefFrom",0,true,0,1,&pushRefFrom),
			NaInstruction("writeTo",0,true,1,0,&writeTo),
			NaInstruction("writeToRef",0,2,0,&writeToRef),
			NaInstruction("deref",0,1,1,&deref),
			NaInstruction("pop",0,1,0,&pop),
			NaInstruction("popN",0,true,255,0,&popN),
			NaInstruction("jump",0,true,true,0,0,&jump),
			NaInstruction("jumpIf",0,true,true,1,0,&jumpIf),
			NaInstruction("jumpStack",0,true,true,0,0,&jumpStack),
			NaInstruction("jumpBack",0,&jumpBack),
			NaInstruction("makeArray",0,true,255,1,&makeArray),
			NaInstruction("arrayRefElement",0,2,1,&arrayRefElement),
			NaInstruction("arrayElement",0,2,1,&arrayElement),
			NaInstruction("arrayLength",0,1,1,&arrayLength),
			NaInstruction("arrayLengthSet",0,2,0,&arrayLengthSet),
			NaInstruction("concatenate",0,2,1,&concatenate),
			NaInstruction("appendElement",0,2,0,&appendElement),
			NaInstruction("appendArrayRef",0,2,0,&appendArrayRef),
			NaInstruction("appendArray",0,2,0,&appendArray),
			NaInstruction("copyArray",0,1,1,&copyArray),
			NaInstruction("copyarrayRef",0,1,1,&copyArrayRef),
			NaInstruction("intToDouble",0,1,1,&intToDouble),
			NaInstruction("intToString",0,1,1,&intToString),
			NaInstruction("boolToString",0,1,1,&boolToString),
			NaInstruction("stringToBool",0,1,1,&stringToBool),
			NaInstruction("doubleToInt",0,1,1,&doubleToInt),
			NaInstruction("doubleToString",0,1,1,&doubleToString),
			NaInstruction("stringToInt",0,1,1,&stringToInt),
			NaInstruction("stringToDouble",0,1,1,&stringToDouble),
			NaInstruction("terminate",0,1,0,&terminate),
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

	/// Starts execution of byte code, starting with the instruction at `index`
	/// 
	/// Returns: what the function returned, or `NaData(0)`
	NaData execute(uinteger index){
		if (!_instructions.length)
			return NaData(0);
		if (_stack.count)
			_stack.pop(_stack.count);
		_inst = &(_instructions[0]);
		_arg = &(_arguments[0]);
		const void delegate()* lastInst = &_instructions[$-1]+1;
		do{
			(*_inst)();
			_inst++;
			_arg++;
		}while (_inst < lastInst);
		if (_stack.count)
			return _stack.pop;
		return NaData();
	}
}