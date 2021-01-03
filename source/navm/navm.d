module navm.navm;

import navm.defs;
import navm.bytecodedefs;
import navm.bytecode;

import std.conv : to;

import utils.lists;
import utils.misc : uinteger, integer;

/// external function
public alias ExternFunction = NaData delegate(NaData[]);
public alias NaData = navm.defs.NaData;
public alias NaInstruction = navm.bytecodedefs.NaInstruction;
public alias readData = navm.bytecode.readData;

/// the VM
class NaVM{
private:
	void delegate()[] _instructions; /// instructions of loaded byte code
	NaData[] _arguments; /// argument of each instruction
	NaData _arg; /// argument of current instruct
	void delegate()* _nextInstruction; /// pointer to next instruction
	NaData* _nextArgument; /// pointer to next instruction's arguments
	NaStack _stack; /// as the name says, stack
	NaData _returnVal; /// return value 
	
	ExternFunction[] _externFunctions; /// external functions 
protected:
	// instructions:

	void call(){
		_stack.push(
			_externFunctions[_arg.intVal](
				_stack.pop(_stack.pop().intVal)
				)
			);
	}

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
		_stack.push(_arg);
	}
	void pushFrom(){
		_stack.push(_stack.read(_arg.intVal));
	}
	void pushRefFrom(){
		_stack.push(NaData(_stack.readPtr(_arg.intVal)));
	}
	void writeTo(){
		_stack.write(_arg.intVal,_stack.pop);
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
		_nextInstruction = &(_instructions)[_arg.intVal] - 1;
		_nextArgument = &(_arguments)[_arg.intVal] - 1;
	}
	void jumpIf(){
		if (_stack.pop.intVal == 1){
			_nextInstruction = &(_instructions)[_arg.intVal] - 1;
			_nextArgument = &(_arguments)[_arg.intVal] - 1;
		}
	}

	void makeArray(){
		_stack.push(NaData(_stack.pop((_arg).intVal).dup));
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

	void returnVal(){
		_returnVal = _stack.pop;
	}
	void terminate(){
		_nextInstruction = &(_instructions)[$-1] + 1;
	}
public:
	/// constructor
	/// 
	/// External Functions get added here
	this(ExternFunction[] externalFunctions){
		_externFunctions = externalFunctions.dup;
	}
	/// destructor
	~this(){

	}
	/// Loads functions into VM, prepares them for execution
	/// 
	/// Returns: true if there was no error, false in the following cases:  
	/// * More than 1 function is of type onLoad  
	/// * In some function, .instruction.length != .arguments.length  
	/// * Invalid instruction used  
	bool load(){
		// TODO
		return true;
	}

	/// Starts execution of byte code, starting with the instruction at `index`
	/// 
	/// Returns: what the function returned, or `NaData(0)`
	NaData execute(uinteger index){
		if (!_instructions.length)
			return NaData(0);
		_stack = new NaStack(1024);
		_returnVal = NaData(0);
		_nextInstruction = &(_instructions[0]);
		_nextArgument = &(_arguments[0]);
		void delegate()* lastInst = &_instructions[$-1]+1;
		do{
			(*_nextInstruction)();
			_nextInstruction++;
			_nextArgument++;
		}while (_nextInstruction < lastInst);
		return _returnVal;
	}
}