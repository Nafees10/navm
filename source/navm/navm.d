module navm.navm;

import navm.defs;
import navm.bytecodedefs;

import utils.lists;
import utils.misc : uinteger, integer;

public import navm.defs : ExternFunction;
public import navm.defs : NaData;


/// the VM (where the ~~magic~~executon happens)
class NaVM{
private:
	NaFunction[] _functions; /// functions loaded
	NaFunction _currentFunction; /// function currently being executed
	Stack!NaFunction _callStack; /// as the name says, call stack
	
	void delegate()* _instruction; /// pointer to next instruction
	NaData* _arguments; /// pointer to next instruction's arguments
	NaStack _stack; /// as the name says, stack
	
	ExternFunction[uinteger] _externFunctions; /// external functions 
protected:
	// instructions:

	void executeExternalFunction(NaStack* _stack, ref NaData* _arguments){
		_stack.push(
			_externFunctions[_arguments[0].intVal](
				_stack.pop(_arguments[1].intVal)
				)
			);
		_arguments++;
		(*(++_instruction))();
	}
	void executeFunction(){
		_stack.push(
			this.execute(
				_arguments[0].intVal,
				_stack.pop(_arguments[1].intVal)
				)
			);
		_arguments++;
		(*(++_instruction))();
	}

	void mathAddInt(){
		_stack.push(
			NaData(_stack.pop.intVal + _stack.pop.intVal)
			);
		(*(++_instruction))();
	}
	void mathSubtractInt(){

	}
	void mathMultiplyInt(){

	}
	void mathDivideInt(){
		
	}
	void mathModInt(){

	}

	void mathAddDivide(){

	}
	void mathSubtractDivide(){

	}
	void mathMultiplyDivide(){

	}
	void mathDivideDivide(){
		
	}
	void mathModDivide(){

	}
public:




	/// Calls a function
	/// 
	/// Returns: what that function returned
	NaData execute(uinteger functionId, NaData[] arguments){

	}
}