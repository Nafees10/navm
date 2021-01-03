module navm.bytecodedefs;

import utils.misc;

import navm.defs;
import navm.bytecode : readData;

import std.conv : to;

/// Class used for storing/constructing bytecode
package class NaBytecode{
private:
	/// where the bytecode is actually stored
	string[] _instructions;
	string[] _arguments;
	/// stores number of elements sitting on stack right now after the last added instruction would be executed
	uinteger _stackLength;
	/// stores max number of elements sitting on stack at any time
	uinteger _stackLengthMax;
	/// stores any elements that have been "bookmarked". Useful for keeping track of elements during constructing byte code
	uinteger[uinteger] _bookmarks;
	/// stores the instruction table
	NaInstruction[] _instructionTable;
public:
	this(NaInstruction[] instructionTable){
		_instructionTable = instructionTable.dup;
	}
	~this(){
		// nothing to do
	}
	/// Returns: true if a NaInstruction exists in instruction table
	bool hasInstruction(string name, ref NaInstruction instruction){
		foreach (inst; _instructionTable){
			if (name.lowercase == inst.name){
				instruction = inst;
				return true;
			}
		}
		return false;
	}
	/// ditto
	bool hasInstruction(string name){
		NaInstruction dummy;
		return hasInstruction(name, dummy);
	}
	/// adds an instruction to the instruction table
	/// 
	/// Returns: true if it was added, false if not due to name or code already used
	bool addInstructionToTable(NaInstruction instruction){
		foreach (inst; _instructionTable){
			if (inst.name == instruction.name || inst.code == instruction.code)
				return false;
		}
		_instructionTable ~= instruction;
		return true;
	}
	/// goes over bytecode, checks if there are any errors, and converts jump positions to indexes
	/// i.e: makes the byte code a bit more ready for execution
	/// 
	/// Returns: errors in a string[], or an empty array in case no errors
	string[] resolve(){
		string[] errors;
		uinteger[string] jumpPos;
		uinteger instCount = 0;
		for (uinteger i=0, instIndex=0; i < _instructions.length; i ++){
			string name = _instructions[i];
			if (name.length && name[$-1] == ':'){
				name = name[0 .. $-1];
				if (name in jumpPos){
					errors ~= "line#"~(i+1).to!string~' '~name~" as jump postion declared multiple times";
					continue;
				}
				jumpPos[name.lowercase] = instIndex;
				continue;
			}
			instIndex ++;
			instCount = instIndex;
		}
		for (uinteger i=0, writeIndex=0; i < _instructions.length; i ++){
			string name = _instructions[i];
			if (name.length && name[$-1] == ':')
				continue;
			if (writeIndex != i){
				_instructions[writeIndex] = name;
				_arguments[writeIndex] = _arguments[i];
			}
			NaInstruction instInfo;
			if (this.hasInstruction(name, instInfo)){
				if (instInfo.needsArg && !_arguments[writeIndex].length)
					errors ~= "line#"~(i+1).to!string~' '~name~"  needs argument";
				if (instInfo.argIsJumpPos){
					string arg = _arguments[writeIndex].lowercase;
					if (arg !in jumpPos)
						errors ~= "line#"~(i+1).to!string~' '~arg~" is not a valid jump position";
					_arguments[writeIndex] = jumpPos[arg].to!string;
				}
			}else
				errors ~= "line#"~(i+1).to!string~" instruction does not exist";
			writeIndex ++;
		}
		_instructions.length = instCount;
		_arguments.length = instCount;
		return errors;
	}
	/// Returns: the bytecode in a readable format
	string[] getBytecodePretty(){
		string[] r;
		r.length = _instructions.length;
		foreach (i, inst; _instructions){
			r[i] = _instructions[i];
			if (_arguments[i].length)
				r[i] ~= "\t\t" ~ _arguments[i];
		}
		return r;
	}
	/// Call `resolve` before this or prepare for crashes
	/// 
	/// Returns: pointers for all instructions
	void delegate()*[] getBytecodePointers(){
		void delegate()*[] r;
		r.length = _instructions.length;
		foreach (i, inst; _instructions){
			NaInstruction instInfo;
			hasInstruction(inst, instInfo);
			r[i] = instInfo.pointer;
		}
		return r;
	}
	/// Call `resolve` before this or prepare for crashes
	/// 
	/// Returns: codes for all instructions
	ushort[] getBytecodeCodes(){
		ushort[] r;
		r.length = _instructions.length;
		foreach (i, inst; _instructions){
			NaInstruction instInfo;
			hasInstruction(inst, instInfo);
			r[i] = instInfo.code;
		}
		return r;
	}
	/// Call `resolve` before this.
	/// 
	/// Returns: arguments for each instruction as NaData, or [] if error
	NaData[] getArgumentsNaData(){
		NaData[] r;
		r.length = _arguments.length;
		foreach (i, arg; _arguments){
			try{
				r[i] = readData(arg);
			}catch (Exception e){
				r = [];
				break;
			}
		}
		return r;
	}
	// functions for generating byte code
	
	/// appends an instruction
	/// 
	/// Returns: true if successful, false if not (writes error in `error`)
	bool addInstruction(string instName, string argument, ref string error){
		import navm.bytecode : removeWhitespace;
		NaInstruction inst;
		if (hasInstruction(instName, inst)){
			if (inst.needsArg && !removeWhitespace(argument).length){
				error = "instruction needs an argument";
				return false;
			}
			NaData arg;
			if (inst.needsArg && !inst.argIsJumpPos){
				try{
					arg = readData(argument);
				}catch (Exception e){
					error = "invalid argument: "~e.msg;
					return false;
				}
				if (_stackLength < inst.popCount(arg)){
					error = "stack does not have enough elements for instruction";
					return false;
				}
			}
			_instructions ~= instName;
			_arguments ~= argument;
			_stackLength -= inst.popCount(arg);
			_stackLength += inst.pushCount;
			_stackLengthMax = _stackLength > _stackLengthMax ? _stackLength : _stackLengthMax;
			return true;
		}
		error = "instruction does not exist";
		return false;
	}
	/// ditto
	bool addInstruction(string instName, string argument){
		string dummy;
		return addInstruction(instName, argument, dummy);
	}
	/// adds a jump position
	void addJumpPos(string name){
		_instructions ~= name~':';
		_arguments ~= "";
	}
	/// Returns: the number of elements on stack after executing the last added instruction
	@property uinteger elementCount(){
		return _stackLength;
	}
	/// adds a "bookmark" to the last element on stack, so later on, relative to current peek index, bookmark index
	/// can be read.
	/// 
	/// Returns: bookmark id, or -1 if stack empty
	integer addBookmark(){
		if (_stackLength == 0)
			return -1;
		integer bookmarkId;
		for (bookmarkId = 0; bookmarkId <= integer.max; bookmarkId ++)
			if (bookmarkId !in _bookmarks)
				break;
		_bookmarks[bookmarkId] = _stackLength-1;
		return bookmarkId;
	}
	/// removes a bookmark
	/// 
	/// Returns: true if successful, false if does not exists
	bool removeBookmark(uinteger id){
		if (id !in _bookmarks)
			return false;
		_bookmarks.remove(id);
		return true;
	}
	/// gets relative index from current stack index to a bookmark
	/// 
	/// Returns: relative index, or integer.max if bookmark does not exist
	integer bookmarkRelIndex(uinteger id){
		if (id !in _bookmarks)
			return integer.max;
		return _stackLength.to!integer - (_bookmarks[id]+1).to!integer;
	}
}

/// stores an data about available instruction
public struct NaInstruction{
	bool argIsJumpPos = false; /// if the argument to this instruction is a jump position
	string name; /// name of instruction, in lowercase
	ushort code = 0x0000; /// value when read as a ubyte
	bool needsArg; /// if this instruction needs an argument
	ubyte pushCount = 0; /// number of elements it will push to stack
	private ubyte _popCount = 0; /// number of elements it will pop (if ==255, then the argument is the number of elements to pop)
	void delegate()* pointer; /// pointer to the delegate behind this instruction
	/// Returns: number of elements it will pop
	ubyte popCount(NaData arg){
		if (_popCount < 255)
			return _popCount;
		return cast(ubyte)(arg.intVal);
	}
	/// constructor, for instruction with no arg, no push/pop
	this (string name, ushort code, void delegate()* pointer){
		this.name = name;
		this.code = code;
		this.pointer = pointer;
		this.needsArg = false;
		this.pushCount = 0;
		this._popCount = 0;
	}
	/// constructor, for instruction with arg
	this (string name, ushort code, bool argIsJumpPos, void delegate()* pointer){
		this.name = name;
		this.code = code;
		this.argIsJumpPos = argIsJumpPos;
		this.pointer = pointer;
		this.needsArg = true;
		this.pushCount = 0;
		this._popCount = 0;
	}
	/// full constructor
	this (string name, ushort code, bool needsArg, bool argIsJumpPos, ubyte pushCount, ubyte popCount, void delegate()* pointer){
		this.name = name;
		this.code = code;
		this.needsArg = needsArg;
		this.argIsJumpPos = argIsJumpPos;
		this.pushCount = pushCount;
		this._popCount = popCount;
		this.pointer = pointer;
	}
}

/// stores an instruction
public enum Instruction : ubyte{
	ExecuteFunctionExternal = 0x00,/// Executes external function. Function id is arg0(int), Argument count is arg1(int)
	ExecuteFunction = 0x01,/// Executes another function defined in byte code. Function id is arg0(int), Argument count is arg1(int)

	MathAddInt = 0x02,/// Addition (integer). PoppedFirst + PoppedSecond
	MathSubtractInt = 0x03,/// Subtraction (integer). PoppedFirst - PoppedSecond
	MathMultiplyInt = 0x04,/// Multiplication (integer). PoppedFirst * PoppedSecond
	MathDivideInt = 0x05,/// Division (integer). PoppedFirst / PoppedSecond
	MathModInt = 0x06,/// Mod (% operator) (integer). PoppedFirst % PoppedSecond

	MathAddDouble = 0x12,/// Addition (double). PoppedFirst + PoppedSecond
	MathSubtractDouble = 0x13,/// Subtraction (double). PoppedFirst - PoppedSecond
	MathMultiplyDouble = 0x14,/// Multiplication (double). PoppedFirst * PoppedSecond
	MathDivideDouble = 0x15,/// Division (double). PoppedFirst / PoppedSecond
	MathModDouble = 0x16,/// Mod (% operator) (double). PoppedFirst % PoppedSecond
	
	IsSame = 0x07,/// Pushes 1(integer) to stack if last two integers popped are same, else, pushes 0(integer)
	IsSameArray = 0x08, /// Pushes 1(integer) if 2 arrays (1 dimensional), popped from stack, have same values, else, pushes 0(integer)
	IsSameArrayRef = 0x09, /// Pushes 1(integer) if 2 arrays (1 dimensional), whose refs are popped from stack, have same values, else, pushes 0(integer)
	
	IsGreaterInt = 0x10,/// Pops A, then B. Pushes 1 if A > B (integer), else, pushes 0(integer)
	IsGreaterSameInt = 0x1A,/// Pops A, then B. Pushes 1 if A >= B (integer), else, pushes 0(integer)

	IsGreaterDouble = 0x11,/// Pops A, then B. Pushes 1 if A > B (double), else, pushes 0(integer)
	IsGreaterSameDouble = 0x1B,/// Pops A, then B. Pushes 1 if A > B (double), else, pushes 0(integer)

	Not = 0x20,/// Pops A(int). Pushes `not A`
	And = 0x21,/// Pops A(int) then B(int). Pushes `A && B`
	Or = 0x22,/// Pops A(int) then B(int). Pushes `A || B`

	Push = 0x30,/// pushes one value to stack. Value is arg0(any data type)
	PushFrom = 0x31,/// reads value at index arg0(int) on stack, pushes it to stack
	PushRefFrom = 0x32, /// Pushes a reference-to-element-at-index-arg0 to stack
	WriteTo = 0x33, /// Pops a value from stack, writes it to an index arg0(int) on stack
	WriteToRef = 0x34, /// pops a ref and then a value, writes value to ref
	Deref = 0x35, /// Pushes the value that is being referenced by a reference popped from stack
	Pop = 0x37,/// Pops one value from stack
	PopN = 0x38, /// Pops n (arg0, int) number of elements from stack
	Jump = 0x39, /// jumps to instruction at index N
	JumpIf = 0x3A, /// jump but checks if value popped from stack == 1(int) before jumping

	MakeArray = 0x40, /// pushes array with N number of elemets, read from stack
	ArrayRefElement = 0x41, /// pops a ref-to-array, then an index. Pushes ref-to-element at that index in that array
	ArrayElement = 0x42, /// pops an array, then an index. Pushes ref-to-element at that index in that array
	ArrayLength = 0x43, /// pops array popped from stack, pushes length of array to stack
	ArrayLengthSet = 0x44, /// Pops a ref-to-array, then length. Sets length of array to popped length.
	Concatenate = 0x45, /// Pops an array(a1), then pops another(a2). Pushes `a1 + a2`
	AppendElement = 0x46, /// Pops a ref-to-array, then an element. Appends element at end of array
	AppendArrayRef = 0x47, /// Pops ref-to-array (r1), then another ref-to-array (r2). then does `*r1 = *r1 + *r2`
	AppendArray = 0x48, /// Pops ref-to-array (r1), then an array (r2). then does `*r1 = *r1 + r2`
	CopyArray = 0x49, /// Pops an array, makes a copy of it, pushes the copy to stack
	CopyArrayRef = 0x4A, /// Pops a ref-to-array, makes a copy of the array, pushes the copy (**not ref-to-copy**) to stack 

	IntToDouble = 0x60, /// pushes double with the same value as int poped from stack
	IntToString = 0x61, /// pushes a string representation of an int popped from stack
	DoubleToInt = 0x62, /// pushes int with same integer value as double poped from stack
	DoubleToString = 0x63, /// pushes a string representation of a double popped from stack
	StringToInt = 0x64, /// pushes an integer read from string, which is popped from stack
	StringToDouble = 0x65, /// pushes an integer read from string, which is popped from stack

	GlobalVarCount = 0x70, /// Sets the number of global variables available to N (arg0, int). Preferably, call once in OnLoad function, as it is slow. All global variables will be resset to 0
	GlobalVarGet = 0x71, /// Pushes the value of global variable with ID N(int, arg0)
	GlobalVarGetRef = 0x72, /// Pushes the reference of global variable with ID N(int, arg0)
	GlobalVarSet = 0x73, /// Pops a value from stack, assigns it to global variable with ID N(int, arg0)

	ReturnVal = 0xF0, /// Pops value, sets it to the return value of currently executed function. Does **NOT** terminate execution
	Terminate = 0xFF, /// Terminates execution of function
}

/// stores number of arguments an instruction needs
public static ubyte[Instruction] INSTRUCTION_ARG_COUNT;


/// stores how many elements an instruction will push to stack
public static ubyte[Instruction] INSTRUCTION_PUSH_COUNT;

/// stores how many elements an instruction will pop from stack. 
/// if number is negative, then it indicates what argument dictates pop_count. i.e, if -1, will pop arg0 number of elements, if -2, then arg1...
private static byte[Instruction] INSTRUCTION_POP_COUNT;

static this(){
	INSTRUCTION_ARG_COUNT = [
		Instruction.ExecuteFunctionExternal : 2,
		Instruction.ExecuteFunction : 2,

		Instruction.MathAddInt : 0,
		Instruction.MathSubtractInt : 0,
		Instruction.MathMultiplyInt : 0,
		Instruction.MathDivideInt : 0,
		Instruction.MathModInt : 0,

		Instruction.MathAddDouble : 0,
		Instruction.MathSubtractDouble : 0,
		Instruction.MathMultiplyDouble : 0,
		Instruction.MathDivideDouble : 0,
		Instruction.MathModDouble : 0,

		Instruction.IsSame : 0,
		Instruction.IsSameArray : 0,
		Instruction.IsSameArrayRef : 0,

		Instruction.IsGreaterInt : 0,
		Instruction.IsGreaterSameInt : 0,

		Instruction.IsGreaterDouble : 0,
		Instruction.IsGreaterSameDouble : 0,

		Instruction.And : 0,
		Instruction.Not : 0,
		Instruction.Or : 0,

		Instruction.Push : 1,
		Instruction.PushFrom : 1,
		Instruction.PushRefFrom : 1,
		Instruction.WriteTo : 1,
		Instruction.WriteToRef : 0,
		Instruction.Deref : 0,
		Instruction.Pop : 0,
		Instruction.PopN : 1,
		Instruction.Jump : 1,
		Instruction.JumpIf : 1,

		Instruction.MakeArray : 1,
		Instruction.ArrayRefElement : 0,
		Instruction.ArrayElement : 0,
		Instruction.ArrayLength : 0,
		Instruction.ArrayLengthSet : 0,
		Instruction.Concatenate : 0,
		Instruction.AppendElement : 0,
		Instruction.AppendArrayRef : 0,
		Instruction.AppendArray : 0,
		Instruction.CopyArray : 0,
		Instruction.CopyArrayRef : 0,

		Instruction.IntToDouble : 0,
		Instruction.IntToString : 0,
		Instruction.DoubleToInt : 0,
		Instruction.DoubleToString : 0,
		Instruction.StringToInt : 0,
		Instruction.StringToDouble : 0,

		Instruction.GlobalVarCount : 1,
		Instruction.GlobalVarGet : 1,
		Instruction.GlobalVarGetRef : 1,
		Instruction.GlobalVarSet : 1,

		Instruction.ReturnVal : 0,
		Instruction.Terminate : 0,
	];

	INSTRUCTION_PUSH_COUNT = [
		Instruction.ExecuteFunctionExternal : 1,
		Instruction.ExecuteFunction : 1,

		Instruction.MathAddInt : 1,
		Instruction.MathSubtractInt : 1,
		Instruction.MathMultiplyInt : 1,
		Instruction.MathDivideInt : 1,
		Instruction.MathModInt : 1,

		Instruction.MathAddDouble : 1,
		Instruction.MathSubtractDouble : 1,
		Instruction.MathMultiplyDouble : 1,
		Instruction.MathDivideDouble : 1,
		Instruction.MathModDouble : 1,

		Instruction.IsSame : 1,
		Instruction.IsSameArray : 1,
		Instruction.IsSameArrayRef : 1,

		Instruction.IsGreaterInt : 1,
		Instruction.IsGreaterSameInt : 1,

		Instruction.IsGreaterDouble : 1,
		Instruction.IsGreaterSameDouble : 1,

		Instruction.And : 1,
		Instruction.Not : 1,
		Instruction.Or : 1,

		Instruction.Push : 1,
		Instruction.PushFrom : 1,
		Instruction.PushRefFrom : 1,
		Instruction.WriteTo : 0,
		Instruction.WriteToRef : 0,
		Instruction.Deref : 1,
		Instruction.Pop : 0,
		Instruction.PopN : 0,
		Instruction.Jump : 0,
		Instruction.JumpIf : 0,

		Instruction.MakeArray : 1,
		Instruction.ArrayRefElement : 1,
		Instruction.ArrayElement : 1,
		Instruction.ArrayLength : 1,
		Instruction.ArrayLengthSet : 0,
		Instruction.Concatenate : 1,
		Instruction.AppendElement : 0,
		Instruction.AppendArrayRef : 0,
		Instruction.AppendArray : 0,
		Instruction.CopyArray : 1,
		Instruction.CopyArrayRef : 1,

		Instruction.IntToDouble : 1,
		Instruction.IntToString : 1,
		Instruction.DoubleToInt : 1,
		Instruction.DoubleToString : 1,
		Instruction.StringToInt : 1,
		Instruction.StringToDouble : 1,

		Instruction.GlobalVarCount : 0,
		Instruction.GlobalVarGet : 1,
		Instruction.GlobalVarGetRef : 1,
		Instruction.GlobalVarSet : 0,

		Instruction.ReturnVal : 0,
		Instruction.Terminate : 0,
	];

	INSTRUCTION_POP_COUNT = [
		Instruction.ExecuteFunctionExternal : -2,
		Instruction.ExecuteFunction : -2,

		Instruction.MathAddInt : 2,
		Instruction.MathSubtractInt : 2,
		Instruction.MathMultiplyInt : 2,
		Instruction.MathDivideInt : 2,
		Instruction.MathModInt : 2,

		Instruction.MathAddDouble : 2,
		Instruction.MathSubtractDouble : 2,
		Instruction.MathMultiplyDouble : 2,
		Instruction.MathDivideDouble : 2,
		Instruction.MathModDouble : 2,

		Instruction.IsSame : 2,
		Instruction.IsSameArray : 2,
		Instruction.IsSameArrayRef : 2,

		Instruction.IsGreaterInt : 2,
		Instruction.IsGreaterSameInt : 2,

		Instruction.IsGreaterDouble : 2,
		Instruction.IsGreaterSameDouble : 2,

		Instruction.And : 2,
		Instruction.Not : 1,
		Instruction.Or : 2,

		Instruction.Push : 0,
		Instruction.PushFrom : 0,
		Instruction.PushRefFrom : 0,
		Instruction.WriteTo : 1,
		Instruction.WriteToRef : 2,
		Instruction.Deref : 1,
		Instruction.Pop : 1,
		Instruction.PopN : -1,
		Instruction.Jump : 0,
		Instruction.JumpIf : 1,

		Instruction.MakeArray : -1,
		Instruction.ArrayRefElement : 2,
		Instruction.ArrayElement : 2,
		Instruction.ArrayLength : 1,
		Instruction.ArrayLengthSet : 2,
		Instruction.Concatenate : 2,
		Instruction.AppendElement : 2,
		Instruction.AppendArrayRef : 2,
		Instruction.AppendArray : 2,
		Instruction.CopyArray : 1,
		Instruction.CopyArrayRef : 1,

		Instruction.IntToDouble : 1,
		Instruction.IntToString : 1,
		Instruction.DoubleToInt : 1,
		Instruction.DoubleToString : 1,
		Instruction.StringToInt : 1,
		Instruction.StringToDouble : 1,

		Instruction.GlobalVarCount : 0,
		Instruction.GlobalVarGet : 0,
		Instruction.GlobalVarGetRef : 0,
		Instruction.GlobalVarSet : 1,

		Instruction.ReturnVal : 1,
		Instruction.Terminate : 0,
	];
}


/// Returns: number of elements an instruction will pop from stack
/// 
/// Throws: Exception if wrong number of arguments provided
public uinteger instructionPopCount(Instruction inst, NaData[] arguments){
	if (inst !in INSTRUCTION_POP_COUNT)
		throw new Exception("unknown instruction provided");
	if (INSTRUCTION_ARG_COUNT[inst] != arguments.length)
		throw new Exception("wrong number of arguments provided for instruction");
	integer count = INSTRUCTION_POP_COUNT[inst];
	if (count >= 0)
		return count;
	count = (count * -1 ) - 1;
	return arguments[count].intVal;

}