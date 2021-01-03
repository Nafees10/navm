module navm.navm;

import navm.defs;
import navm.bytecodedefs;
import navm.bytecode;

import std.conv : to;

import utils.lists;
import utils.misc : uinteger, integer;
/*
alias ExternFunction = navm.defs.ExternFunction;
alias NaData = navm.defs.NaData;
alias Instruction = navm.bytecodedefs.Instruction;
alias NaFunction = navm.bytecodedefs.NaFunction;
alias readData = navm.bytecode.readData;


/// the VM
class NaVM{
private:
	void delegate()[][] _functions; /// instructions of functions loaded
	uinteger[] _functionsStackLength;
	NaData[][][] _functionsArguments; /// arguments of each functions' each instruction

	void delegate()[] _onloadInstructions; /// instructions for onLoad function
	uinteger _onloadStackLength; /// stack length of onLoad function
	NaData[][] _onloadArguments; /// arguments for isntructions of onLoad function

	bool _onloadExists; /// if onLoad function exists
	bool _onloadExecuted; /// if onLoad has been executed

	void delegate()[]* _currentFunction; /// instructions of function currently being executed
	NaData[][]* _currentArguments; /// arguments of instructions of function currently being executed

	NaData[] _globalVars; /// stores global variables for a bytecode
	
	void delegate()* _instruction; /// pointer to next instruction
	NaData[]* _arguments; /// pointer to next instruction's arguments
	NaStack _stack; /// as the name says, stack
	NaData _returnVal; /// return value of current function
	
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
		_stack.push(NaData(cast(integer)(_stack.pop.intVal == _stack.pop.intVal)));
	}
	void isSameArray(){
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
	void isSameArrayRef(){
		NaData[] a = _stack.pop.ptrVal.arrayVal, b = _stack.pop.ptrVal.arrayVal;
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

	void isGreaterInt(){
		_stack.push(NaData(cast(integer)(_stack.pop.intVal > _stack.pop.intVal)));
	}
	void isGreaterSameInt(){
		_stack.push(NaData(cast(integer)(_stack.pop.intVal >= _stack.pop.intVal)));
	}

	void isGreaterDouble(){
		_stack.push(NaData(cast(integer)(_stack.pop.doubleVal > _stack.pop.doubleVal)));
	}
	void isGreaterSameDouble(){
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
		_stack.pop((*_arguments)[0].intVal);
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
		/// ~= evaluates right side first unfortunately
		NaData arrayPtr = _stack.pop;
		arrayPtr.ptrVal.arrayVal ~= _stack.pop;
	}
	void appendArrayRef(){
		/// ~= evaluates right side first unfortunately
		NaData arrayPtr = _stack.pop;
		arrayPtr.ptrVal.arrayVal ~= (*(_stack.pop.ptrVal)).arrayVal.dup;
	}
	void appendArray(){
		/// ~= evaluates right side first unfortunately
		NaData arrayPtr = _stack.pop;
		arrayPtr.ptrVal.arrayVal ~= _stack.pop.arrayVal.dup;
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
		_stack.push(NaData(to!string(_stack.pop.intVal)));
	}
	void doubleToInt(){
		_stack.push(NaData(to!integer(_stack.pop.doubleVal)));
	}
	void doubleToString(){
		_stack.push(NaData(to!string(_stack.pop.doubleVal)));
	}
	void stringToInt(){
		_stack.push(NaData(to!integer(_stack.pop.strVal)));
	}
	void stringToDouble(){
		_stack.push(NaData(to!double(_stack.pop.strVal)));
	}

	void globalVarCount(){
		_globalVars.length = (*_arguments)[0].intVal;
		foreach (i; 0 .. _globalVars.length)
			_globalVars[i].intVal = 0;
	}
	void globalVarGet(){
		_stack.push(_globalVars[(*_arguments)[0].intVal]);
	}
	void globalVarGetRef(){
		_stack.push(NaData(&_globalVars[(*_arguments)[0].intVal]));
	}
	void globalVarSet(){
		_globalVars[(*_arguments)[0].intVal] = _stack.pop;
	}

	void returnVal(){
		_returnVal = _stack.pop;
	}
	void terminate(){
		_instruction = &(*_currentFunction)[$-1] + 1;
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

			Instruction.IsSame : &isSame,
			Instruction.IsSameArray : &isSameArray,
			Instruction.IsSameArrayRef : &isSameArrayRef,

			Instruction.IsGreaterInt : &isGreaterInt,
			Instruction.IsGreaterSameInt : &isGreaterSameInt,

			Instruction.IsGreaterDouble : &isGreaterDouble,
			Instruction.IsGreaterSameDouble : &isGreaterSameDouble,

			Instruction.And : &binaryAnd,
			Instruction.Not : &binaryNot,
			Instruction.Or : &binaryOr,

			Instruction.Push : &push,
			Instruction.PushFrom : &pushFrom,
			Instruction.PushRefFrom : &pushRefFrom,
			Instruction.WriteTo : &writeTo,
			Instruction.WriteToRef : &writeToRef,
			Instruction.Deref : &deref,
			Instruction.Pop : &pop,
			Instruction.PopN : &popN,
			Instruction.Jump : &jump,
			Instruction.JumpIf : &jumpIf,

			Instruction.MakeArray : &makeArray,
			Instruction.ArrayRefElement : &arrayRefElement,
			Instruction.ArrayElement : &arrayElement,
			Instruction.ArrayLength : &arrayLength,
			Instruction.ArrayLengthSet : &arrayLengthSet,
			Instruction.Concatenate : &concatenate,
			Instruction.AppendElement : &appendElement,
			Instruction.AppendArrayRef : &appendArrayRef,
			Instruction.AppendArray : &appendArray,
			Instruction.CopyArray : &copyArray,
			Instruction.CopyArrayRef : &copyArrayRef,

			Instruction.IntToDouble : &intToDouble,
			Instruction.IntToString : &intToString,
			Instruction.DoubleToInt : &doubleToInt,
			Instruction.DoubleToString : &doubleToString,
			Instruction.StringToInt : &stringToInt,
			Instruction.StringToDouble : &stringToDouble,

			Instruction.GlobalVarCount : &globalVarCount,
			Instruction.GlobalVarGet : &globalVarGet,
			Instruction.GlobalVarGetRef : &globalVarGetRef,
			Instruction.GlobalVarSet : &globalVarSet,

			Instruction.ReturnVal : &returnVal,
			Instruction.Terminate : &terminate,
		];
		// clear existing stuff
		_functions = [];
		_functionsArguments = [];
		_functionsStackLength = [];
		_onloadInstructions = [];
		_onloadArguments = [];
		_onloadStackLength = 0;
		_onloadExecuted = false;
		_onloadExists = false;
		// search for onLoad functions
		foreach (i, func; functions){
			if (func.type == NaFunction.Type.OnLoad){
				functions = functions.dup; // going to modify it, so copy
				// check if some other is onLoad too
				foreach (j; i + 1 .. functions.length)
					if (functions[j].type == NaFunction.Type.OnLoad)
						return false;
				_onloadExists = true;
				_onloadExecuted = false;
				if (func.instructions.length != func.arguments.length)
					return false;
				_onloadInstructions.length = func.instructions.length;
				_onloadArguments.length = func.arguments.length;
				_onloadStackLength = func.stackLength;
				foreach (index, instruction; func.instructions){
					if (instruction !in map)
						return false;
					_onloadInstructions[index] = map[instruction];
					_onloadArguments[index] = func.arguments[index].dup;
				}
				functions = functions[0 .. i].dup ~ functions[i+1 .. $].dup;
				break;
			}
		}
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

	/// Calls the onLoad function if present, and not executed since bytecode loading
	void executeOnLoad(){
		if (_onloadExists && !_onloadExecuted){
			_onloadExecuted = true;
			// start
			_currentFunction = &_onloadInstructions;
			_currentArguments = &_onloadArguments;
			_stack = new NaStack(_onloadStackLength);
			_instruction = &(*_currentFunction)[0];
			_arguments = &(*_currentArguments)[0];
			void delegate()* end = &(*_currentFunction)[$-1];
			end ++;
			while (_instruction < end){
				(*_instruction)();
				_instruction++;
				_arguments++;
			}
			_stack.destroy();
			_currentFunction = null;
			_currentArguments = null;
			_instruction = null;
			_arguments = null;
		}
	}


	/// Calls a function from bytecode. Before calling this, make sure you have called `this.executeOnLoad` to init the bytecode
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
		void delegate()* end = &(*_currentFunction)[$-1];
		end++;// so i can use < instead of <=
		// push args
		_stack.push(arguments);
		// start executing
		while (_instruction < end){
			(*_instruction)();
			_instruction++;
			_arguments++;
		}
		NaData r = _returnVal;
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
}*/