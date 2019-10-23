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

	void executeExternalFunction(){
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
		uinteger bOperand = _stack.pop.intVal;
		_stack.push(
			NaData(_stack.pop.intVal - bOperand)
			);
		(*(++_instruction))();
	}
	void mathMultiplyInt(){
		_stack.push(
			NaData(_stack.pop.intVal * _stack.pop.intVal)
			);
		(*(++_instruction))();
	}
	void mathDivideInt(){
		uinteger bOperand = _stack.pop.intVal;
		_stack.push(
			NaData(_stack.pop.intVal / bOperand)
			);
		(*(++_instruction))();
	}
	void mathModInt(){
		uinteger bOperand = _stack.pop.intVal;
		_stack.push(
			NaData(_stack.pop.intVal % bOperand)
			);
		(*(++_instruction))();
	}

	void mathAddDouble(){
		_stack.push(
			NaData(_stack.pop.doubleVal + _stack.pop.doubleVal)
			);
		(*(++_instruction))();
	}
	void mathSubtractDouble(){
		double bOperand = _stack.pop.doubleVal;
		_stack.push(
			NaData(_stack.pop.doubleVal - bOperand)
			);
		(*(++_instruction))();
	}
	void mathMultiplyDouble(){
		_stack.push(
			NaData(_stack.pop.doubleVal * _stack.pop.doubleVal)
			);
		(*(++_instruction))();
	}
	void mathDivideDouble(){
		double bOperand = _stack.pop.doubleVal;
		_stack.push(
			NaData(_stack.pop.doubleVal / bOperand)
			);
		(*(++_instruction))();
	}
	void mathModDouble(){
		double bOperand = _stack.pop.doubleVal;
		_stack.push(
			NaData(_stack.pop.doubleVal % bOperand)
			);
		(*(++_instruction))();
	}
public:




	/// Calls a function
	/// 
	/// Returns: what that function returned
	NaData execute(uinteger functionId, NaData[] arguments){

	}
}