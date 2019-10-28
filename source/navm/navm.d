module navm.navm;

import navm.defs;
import navm.bytecodedefs;

import std.conv : to;

import utils.lists;
import utils.misc : uinteger, integer;

public import navm.defs : ExternFunction;
public import navm.defs : NaData;


/// the VM (where the ~~magic~~executon happens)
class NaVM{
private:
	void delegate()[][uinteger] _functions; /// instructions of functions loaded
	NaData[][][uinteger] _functionsArguments; /// arguments of each functions' each instruction
	void delegate()[] _currentFunction; /// instructions of function currently being executed
	NaData[][] _currentArguments; /// arguments of instructions of function currently being executed
	
	void delegate()* _instruction; /// pointer to next instruction
	NaData[]* _arguments; /// pointer to next instruction's arguments
	NaStack _stack; /// as the name says, stack
	NaData _returnVal; /// return value of current function
	
	ExternFunction[uinteger] _externFunctions; /// external functions 
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
		NaData[] a = *(_stack.pop.arrayVal), b = *(_stack.pop.arrayVal);
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
		NaData[] a = *(_stack.pop.arrayVal), b = *(_stack.pop.arrayVal);
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
	void pushTo(){
		_stack.write((*_arguments)[0].intVal,_stack.pop);
	}
	void deref(){
		_stack.push(*(_stack.pop.ptrVal));
	}
	void pop(){
		_stack.pop;
	}
	void jump(){
		_instruction = &_currentFunction[(*_arguments)[0].intVal] - 1;
		_arguments = &_currentArguments[(*_arguments)[0].intVal] - 1;
	}
	void jumpIf(){
		if (_stack.pop.intVal == 1){
			_instruction = &_currentFunction[(*_arguments)[0].intVal] - 1;
			_arguments = &_currentArguments[(*_arguments)[0].intVal] - 1;
		}
	}

	void makeArray(){
		_stack.push(NaData(_stack.pop((*_arguments)[0].intVal)));
	}
	void readElement(){
		uinteger index = _stack.pop.intVal;
		_stack.push(NaData(&((*_stack.pop.arrayVal)[index])));
	}
	void arrayLength(){
		_stack.push(NaData((*_stack.pop.arrayVal).length));
	}
	void arrayLengthSet(){
		uinteger length = _stack.pop.intVal;
		(*_stack.pop.arrayVal).length = length;
	}
	void concatenate(){
		NaData[]* b = _stack.pop.arrayVal;
		_stack.push(NaData(*_stack.pop.arrayVal ~ *b));
	}
	void append(){
		NaData element = _stack.pop;
		_stack.push(NaData(*_stack.pop.arrayVal ~ element));
	}

	void intToDouble(){
		_stack.push(NaData(to!double(_stack.pop.intVal)));
	}
	void doubleToInt(){
		_stack.push(NaData(to!integer(_stack.pop.doubleVal)));
	}
public:




	/// Calls a function
	/// 
	/// Returns: what that function returned
	NaData execute(uinteger functionId, NaData[] arguments){

		return _returnVal;
	}
}