module navm.bytecodedefs;

import utils.misc;

import navm.defs;

/// Stores a byte code function (the instructions plus their arguments)
public struct NaFunction{
	Instruction[] instructions; /// the instructions making this function
	NaData[][] arguments; /// arguments for each of the instructions
	uinteger stackLength; /// max number of elements needed on stack
	/// postblit
	this (this){
		this.instructions = instructions.dup;
		NaData[][] newArgs;
		newArgs.length = arguments.length;
		foreach(i, args; arguments){
			newArgs[i] = args.dup;
		}
		arguments = newArgs;
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
	IsSameArray = 0x08, /// Pushes 1(integer) if 2 arrays, popped from stack, have same values, else, pushes 0(integer)
	IsSameArrayRef = 0x09, /// Pushes 1(integer) if 2 arrays, whose refs are popped from stack, have same values, else, pushes 0(integer)
	
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

	IntToDouble = 0x60, /// pushes double with the same value as int poped from stack
	IntToString = 0x61, /// pushes a string representation of an int popped from stack
	DoubleToInt = 0x62, /// pushes int with same integer value as double poped from stack
	DoubleToString = 0x63, /// pushes a string representation of a double popped from stack
	StringToInt = 0x64, /// pushes an integer read from string, which is popped from stack
	StringToDouble = 0x65, /// pushes an integer read from string, which is popped from stack

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

		Instruction.IntToDouble : 0,
		Instruction.IntToString : 0,
		Instruction.DoubleToInt : 0,
		Instruction.DoubleToString : 0,
		Instruction.StringToInt : 0,
		Instruction.StringToDouble : 0,

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

		Instruction.IntToDouble : 1,
		Instruction.IntToString : 1,
		Instruction.DoubleToInt : 1,
		Instruction.DoubleToString : 1,
		Instruction.StringToInt : 1,
		Instruction.StringToDouble : 1,

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
		Instruction.Not : 2,
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

		Instruction.IntToDouble : 1,
		Instruction.IntToString : 1,
		Instruction.DoubleToInt : 1,
		Instruction.DoubleToString : 1,
		Instruction.StringToInt : 1,
		Instruction.StringToDouble : 1,

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