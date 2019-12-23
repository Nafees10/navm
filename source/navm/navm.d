module navm.navm;

import navm.defs;
import navm.bytecodedefs;
import navm.bytecode;

import std.conv : to;

import utils.lists;
import utils.misc : uinteger, integer;

public import navm.defs : ExternFunction;
public import navm.defs : NaData;


/// the VM (where the ~~magic~~executon happens)
class NaVM{
private:
	void delegate()[][] _functions; /// instructions of functions loaded
	uinteger[] _functionsStackLength;
	NaData[][][] _functionsArguments; /// arguments of each functions' each instruction

	void delegate()[]* _currentFunction; /// instructions of function currently being executed
	NaData[][]* _currentArguments; /// arguments of instructions of function currently being executed
	
	void delegate()* _instruction; /// pointer to next instruction
	NaData[]* _arguments; /// pointer to next instruction's arguments
	NaStack _stack; /// as the name says, stack
	NaData _returnVal; /// return value of current function
	bool keepRunning; /// set it to false to terminate execution
	
	ExternFunction[] _externFunctions; /// external functions 
protected:
	// instructions:

	void executeExternalFunction(){
		_stack.push(
			_externFunctions[(*_arguments)[0].intVal](
				_stack.pop((*_arguments)[1].intVal)
				)
			);
	}
	void executeFunction(){
		_stack.push(
			this.execute(
				(*_arguments)[0].intVal,
				_stack.pop((*_arguments)[1].intVal)
				)
			);
	}

	void mathAddInt(){
		_stack.push(
			NaData(_stack.pop.intVal + _stack.pop.intVal)
			);
	}
	void mathSubtractInt(){
		uinteger bOperand = _stack.pop.intVal;
		_stack.push(
			NaData(_stack.pop.intVal - bOperand)
			);
	}
	void mathMultiplyInt(){
		_stack.push(
			NaData(_stack.pop.intVal * _stack.pop.intVal)
			);
	}
	void mathDivideInt(){
		uinteger bOperand = _stack.pop.intVal;
		_stack.push(
			NaData(_stack.pop.intVal / bOperand)
			);
	}
	void mathModInt(){
		uinteger bOperand = _stack.pop.intVal;
		_stack.push(
			NaData(_stack.pop.intVal % bOperand)
			);
	}

	void mathAddDouble(){
		_stack.push(
			NaData(_stack.pop.doubleVal + _stack.pop.doubleVal)
			);
	}
	void mathSubtractDouble(){
		double bOperand = _stack.pop.doubleVal;
		_stack.push(
			NaData(_stack.pop.doubleVal - bOperand)
			);
	}
	void mathMultiplyDouble(){
		_stack.push(
			NaData(_stack.pop.doubleVal * _stack.pop.doubleVal)
			);
	}
	void mathDivideDouble(){
		double bOperand = _stack.pop.doubleVal;
		_stack.push(
			NaData(_stack.pop.doubleVal / bOperand)
			);
	}
	void mathModDouble(){
		double bOperand = _stack.pop.doubleVal;
		_stack.push(
			NaData(_stack.pop.doubleVal % bOperand)
			);
	}

	void isSameInt(){
		_stack.push(NaData(cast(integer)(_stack.pop.intVal == _stack.pop.intVal)));
	}
	void isSameArrayInt(){
		NaData[] a = _stack.pop.arrayVal, b = _stack.pop.arrayVal;
		NaData r = NaData(0);
		if (a.length == b.length){
			r = NaData(1);
			NaData* aPtr = &a[0], bPtr = &b[0];
			for (uinteger i = 0; i < a.length; i++){
				if ((*aPtr).intVal != (*bPtr).intVal){
					r = NaData(0);
					break;
				}
				aPtr ++;
				bPtr ++;
			}
		}
		_stack.push(r);
	}
	void isLesserInt(){
		_stack.push(NaData(cast(integer)(_stack.pop.intVal > _stack.pop.intVal)));
	}
	void isLesserSameInt(){
		_stack.push(NaData(cast(integer)(_stack.pop.intVal >= _stack.pop.intVal)));
	}

	void isSameDouble(){
		_stack.push(NaData(cast(integer)(_stack.pop.doubleVal == _stack.pop.doubleVal)));
	}
	void isSameArrayDouble(){
		NaData[] a = _stack.pop.arrayVal, b = _stack.pop.arrayVal;
		NaData r = NaData(0);
		if (a.length == b.length){
			r = NaData(1);
			NaData* aPtr = &a[0], bPtr = &b[0];
			for (uinteger i = 0; i < a.length; i++){
				if ((*aPtr).doubleVal != (*bPtr).doubleVal){
					r = NaData(0);
					break;
				}
				aPtr ++;
				bPtr ++;
			}
		}
		_stack.push(r);
	}
	void isLesserDouble(){
		_stack.push(NaData(cast(integer)(_stack.pop.doubleVal > _stack.pop.doubleVal)));
	}
	void isLesserSameDouble(){
		_stack.push(NaData(cast(integer)(_stack.pop.doubleVal >= _stack.pop.doubleVal)));
	}

	void binaryNot(){
		_stack.push(NaData(cast(integer)(!_stack.pop.intVal)));
	}
	void binaryAnd(){
		_stack.push(NaData(cast(integer)(_stack.pop.intVal && _stack.pop.intVal)));
	}
	void binaryOr(){
		_stack.push(NaData(cast(integer)(_stack.pop.intVal || _stack.pop.intVal)));
	}

	void push(){
		_stack.push(_arguments[0]);
	}
	void pushFrom(){
		_stack.push(_stack.read((*_arguments)[0].intVal));
	}
	void pushRefFrom(){
		_stack.push(NaData(_stack.readPtr((*_arguments)[0].intVal)));
	}
	void writeTo(){
		_stack.write((*_arguments)[0].intVal,_stack.pop);
	}
	void writeToRef(){
		*(_stack.pop.ptrVal) = _stack.pop;
	}
	void deref(){
		_stack.push(*(_stack.pop.ptrVal));
	}
	void pop(){
		_stack.pop;
	}
	void jump(){
		_instruction = &(*_currentFunction)[(*_arguments)[0].intVal] - 1;
		_arguments = &(*_currentArguments)[(*_arguments)[0].intVal] - 1;
	}
	void jumpIf(){
		if (_stack.pop.intVal == 1){
			_instruction = &(*_currentFunction)[(*_arguments)[0].intVal] - 1;
			_arguments = &(*_currentArguments)[(*_arguments)[0].intVal] - 1;
		}
	}

	void makeArray(){
		_stack.push(NaData(_stack.pop((*_arguments)[0].intVal).dup));
	}
	void readElement(){
		uinteger index = _stack.pop.intVal;
		_stack.push(NaData(&((*(_stack.pop.ptrVal)).arrayVal[index])));
	}
	void arrayLength(){
		_stack.push(NaData(_stack.pop.arrayVal.length));
	}
	void arrayLengthSet(){
		uinteger length = _stack.pop.intVal;
		(*(_stack.pop.ptrVal)).arrayVal.length = length;
	}
	void concatenate(){
		NaData[] b = _stack.pop.arrayVal;
		_stack.push(NaData(_stack.pop.arrayVal ~ b));
	}
	void append(){
		NaData element = _stack.pop;
		_stack.push(NaData(_stack.pop.arrayVal ~ element));
	}

	void intToDouble(){
		_stack.push(NaData(to!double(_stack.pop.intVal)));
	}
	void doubleToInt(){
		_stack.push(NaData(to!integer(_stack.pop.doubleVal)));
	}

	void returnVal(){
		_returnVal = _stack.pop;
	}
	void terminate(){
		keepRunning = false;
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
	/// Returns: true if there was no error, false if there was and failed to load (probably because of an instruction not existing)
	bool load(NaFunction[] functions){
		void delegate()[Instruction] map = [
			Instruction.ExecuteFunctionExternal : &executeExternalFunction,
			Instruction.ExecuteFunction : &executeFunction,

			Instruction.MathAddInt : &mathAddInt,
			Instruction.MathSubtractInt : &mathSubtractInt,
			Instruction.MathMultiplyInt : &mathMultiplyInt,
			Instruction.MathDivideInt : &mathDivideInt,
			Instruction.MathModInt : &mathModInt,

			Instruction.MathAddDouble : &mathAddDouble,
			Instruction.MathSubtractDouble : &mathSubtractDouble,
			Instruction.MathMultiplyDouble : &mathMultiplyDouble,
			Instruction.MathDivideDouble : &mathDivideDouble,
			Instruction.MathModDouble : &mathModDouble,

			Instruction.IsSameInt : &isSameInt,
			Instruction.IsSameArrayInt : &isSameArrayInt,
			Instruction.IsLesserInt : &isLesserInt,
			Instruction.IsLesserSameInt : &isLesserSameInt,

			Instruction.IsSameDouble : &isSameDouble,
			Instruction.IsSameArrayDouble : &isSameArrayDouble,
			Instruction.IsLesserDouble : &isLesserDouble,
			Instruction.IsLesserSameDouble : &isLesserSameDouble,

			Instruction.BinaryAnd : &binaryAnd,
			Instruction.BinaryNot : &binaryNot,
			Instruction.BinaryOr : &binaryOr,

			Instruction.Push : &push,
			Instruction.PushFrom : &pushFrom,
			Instruction.PushRefFrom : &pushRefFrom,
			Instruction.WriteTo : &writeTo,
			Instruction.WriteToRef : &writeToRef,
			Instruction.Deref : &deref,
			Instruction.Pop : &pop,
			Instruction.Jump : &jump,
			Instruction.JumpIf : &jumpIf,

			Instruction.MakeArray : &makeArray,
			Instruction.ReadElement : &readElement,
			Instruction.ArrayLength : &arrayLength,
			Instruction.ArrayLengthSet : &arrayLengthSet,
			Instruction.Concatenate : &concatenate,
			Instruction.Append : &append,

			Instruction.IntToDouble : &intToDouble,
			Instruction.DoubleToInt : &doubleToInt,

			Instruction.ReturnVal : &returnVal,
			Instruction.Terminate : &terminate,
		];
		_functions.length = functions.length;
		_functionsArguments.length = functions.length;
		_functionsStackLength.length = functions.length;
		foreach(i, func; functions){
			_functions[i].length = func.instructions.length;
			_functionsArguments[i].length = func.arguments.length;
			_functionsStackLength[i] = func.stackLength;
			// make sure each instruction has args (arrays must match)
			if (func.instructions.length != func.arguments.length)
				return false;
			foreach(index, instruction; func.instructions){
				if (instruction ! in map)
					return false;
				_functions[i][index] = map[instruction];
				_functionsArguments[i][index] = func.arguments[index].dup;
			}
		}
		return true;
	}

	/// Loads byte code
	/// 
	/// Throws: Exception in case of an error in byte code
	void load(string[] code){
		if (!this.load(readByteCode(code)))
			throw new Exception("unexpected error in NaVM.load(NaFunction[])");
	}


	/// Calls a function
	/// 
	/// Returns: what that function returned
	NaData execute(uinteger functionId, NaData[] arguments){
		// save state of previous function
		void delegate()[]* prevFunction = _currentFunction;
		NaData[][]* prevFunctionArguments = _currentArguments;
		void delegate()* prevInstruction = _instruction;
		NaData[]* prevArguments = _arguments;
		NaStack prevStack = _stack;
		NaData prevReturnVal = _returnVal;
		// prepare for this one
		_stack = new NaStack(_functionsStackLength[functionId]);
		_currentFunction = &_functions[functionId];
		_currentArguments = &_functionsArguments[functionId];
		_instruction = &(*_currentFunction)[0];
		_arguments = &(*_currentArguments)[0];
		_returnVal = NaData();
		keepRunning = true;
		// push args
		_stack.push(arguments);
		// start executing
		while (keepRunning){
			(*_instruction)();
			_instruction++;
			_arguments++;
		}
		NaData r = _returnVal;
		keepRunning = true;
		// restore prev state
		_currentFunction = prevFunction;
		_currentArguments = prevFunctionArguments;
		_instruction = prevInstruction;
		_arguments = prevArguments;
		_stack.destroy;
		_stack = prevStack;
		_returnVal = prevReturnVal;
		return r;
	}
}