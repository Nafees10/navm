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
	ExecuteFunctionExternal = 0x00,/// Executes external function
	ExecuteFunction = 0x01,/// Executes another function defined in byte code

	MathAddInt = 0x02,/// Addition (integer)
	MathSubtractInt = 0x03,/// Subtraction (integer)
	MathMultiplyInt = 0x04,/// Multiplication (integer)
	MathDivideInt = 0x05,/// Division (integer)
	MathModInt = 0x06,/// Mod (% operator) (integer)

	MathAddDouble = 0x12,/// Addition (double)
	MathSubtractDouble = 0x13,/// Subtraction (double)
	MathMultiplyDouble = 0x14,/// Multiplication (double)
	MathDivideDouble = 0x15,/// Division (double)
	MathModDouble = 0x16,/// Mod (% operator) (double)
	
	IsSameInt = 0x07,/// if both values are same (integer)
	IsSameArrayInt = 0x08, /// if 2 int[] have same values
	IsLesserInt = 0x09,/// is val0 < val1 (integer)
	IsLesserSameInt = 0x0A,/// if val1 <= val2 (integer)

	IsSameDouble = 0x17,/// if both values are same (double)
	IsSameArrayDouble = 0x18, /// if 2 double[] have same values
	IsLesserDouble = 0x19,/// is val0 < val1 (double)
	IsLesserSameDouble = 0x1A,/// if val1 <= val2 (double)

	BinaryNot = 0x20,/// not operator (integer)
	BinaryAnd = 0x21,/// and operator (integer)
	BinaryOr = 0x22,/// or operator (integer)

	Push = 0x30,/// pushes one value to stack
	PushFrom = 0x31,/// reads value at index arg0 on stack, pushes it to stack
	PushRefFrom = 0x32, /// Pushes a reference-to-element-at-index-arg0 to stack
	WriteTo = 0x33, /// Pops a value from stack, writes it to an index arg0 on stack
	WriteToRef = 0x34, /// pops a ref and then a value, writes value to ref
	Deref = 0x35, /// Pushes the value that is being referenced by a reference pop-ed from stack
	Pop = 0x36,/// Pops one value from stack
	Jump = 0x37, /// jumps to instruction at index N
	JumpIf = 0x38, /// jump but checks if value pop-ed from stack == 1 before jumping

	MakeArray = 0x40, /// pushes array with N number of elemets, read from stack
	ReadElement = 0x41, /// pops an index, then a ref-to-array. Pushes ref to element at that index in that array
	ArrayLength = 0x42, /// Pushes length of array to stack, array pop-ed from stack
	ArrayLengthSet = 0x43, /// Changes length of array (reference to array popped from stack) to new length, pop-ed from stack. Length is poped first
	Concatenate = 0x44,/// Concatenate arrays
	Append = 0x45, /// Appends an element at end of array, pushes new array

	IntToDouble = 0x50,/// pushes doulbe with the same value as int poped from stack
	DoubleToInt = 0x51,/// pushes int with same integer value as double poped from stack

	ReturnVal = 0xF0, /// Pops value, sets it to the return value of currently executed function. Does **NOT** terminate execution
	Terminate = 0xFF, /// Terminates execution of function
}

/// stores number of arguments an instruction needs
public static ubyte[Instruction] INSTRUCTION_ARG_COUNT;


/// stores how many elements an instruction will push to stack
public static ubyte[Instruction] INSTRUCTION_PUSH_COUNT;

/// stores how many elements an instruction will pop from stack (-1 if number varies depending on arguments)
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

		Instruction.IsSameInt : 0,
		Instruction.IsSameArrayInt : 0,
		Instruction.IsLesserInt : 0,
		Instruction.IsLesserSameInt : 0,

		Instruction.IsSameDouble : 0,
		Instruction.IsSameArrayDouble : 0,
		Instruction.IsLesserDouble : 0,
		Instruction.IsLesserSameDouble : 0,

		Instruction.BinaryAnd : 0,
		Instruction.BinaryNot : 0,
		Instruction.BinaryOr : 0,

		Instruction.Push : 1,
		Instruction.PushFrom : 1,
		Instruction.PushRefFrom : 1,
		Instruction.WriteTo : 1,
		Instruction.WriteToRef : 0,
		Instruction.Deref : 0,
		Instruction.Pop : 0,
		Instruction.Jump : 1,
		Instruction.JumpIf : 1,

		Instruction.MakeArray : 1,
		Instruction.ReadElement : 0,
		Instruction.ArrayLength : 0,
		Instruction.ArrayLengthSet : 0,
		Instruction.Concatenate : 0,
		Instruction.Append : 0,

		Instruction.IntToDouble : 0,
		Instruction.DoubleToInt : 0,

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

		Instruction.IsSameInt : 1,
		Instruction.IsSameArrayInt : 1,
		Instruction.IsLesserInt : 1,
		Instruction.IsLesserSameInt : 1,

		Instruction.IsSameDouble : 1,
		Instruction.IsSameArrayDouble : 1,
		Instruction.IsLesserDouble : 1,
		Instruction.IsLesserSameDouble : 1,

		Instruction.BinaryAnd : 1,
		Instruction.BinaryNot : 1,
		Instruction.BinaryOr : 1,

		Instruction.Push : 1,
		Instruction.PushFrom : 1,
		Instruction.PushRefFrom : 1,
		Instruction.WriteTo : 0,
		Instruction.WriteToRef : 0,
		Instruction.Deref : 1,
		Instruction.Pop : 0,
		Instruction.Jump : 0,
		Instruction.JumpIf : 0,

		Instruction.MakeArray : 1,
		Instruction.ReadElement : 1,
		Instruction.ArrayLength : 1,
		Instruction.ArrayLengthSet : 0,
		Instruction.Concatenate : 1,
		Instruction.Append : 1,

		Instruction.IntToDouble : 1,
		Instruction.DoubleToInt : 1,

		Instruction.ReturnVal : 0,
		Instruction.Terminate : 0,
	];

	INSTRUCTION_POP_COUNT = [
		Instruction.ExecuteFunctionExternal : -1,
		Instruction.ExecuteFunction : -1,

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

		Instruction.IsSameInt : 2,
		Instruction.IsSameArrayInt : 2,
		Instruction.IsLesserInt : 2,
		Instruction.IsLesserSameInt : 2,

		Instruction.IsSameDouble : 2,
		Instruction.IsSameArrayDouble : 2,
		Instruction.IsLesserDouble : 2,
		Instruction.IsLesserSameDouble : 2,

		Instruction.BinaryAnd : 2,
		Instruction.BinaryNot : 2,
		Instruction.BinaryOr : 2,

		Instruction.Push : 0,
		Instruction.PushFrom : 0,
		Instruction.PushRefFrom : 0,
		Instruction.WriteTo : 1,
		Instruction.WriteToRef : 2,
		Instruction.Deref : 1,
		Instruction.Pop : 1,
		Instruction.Jump : 0,
		Instruction.JumpIf : 1,

		Instruction.MakeArray : -1,
		Instruction.ReadElement : 2,
		Instruction.ArrayLength : 1,
		Instruction.ArrayLengthSet : 2,
		Instruction.Concatenate : 2,
		Instruction.Append : 2,

		Instruction.IntToDouble : 1,
		Instruction.DoubleToInt : 1,

		Instruction.ReturnVal : 1,
		Instruction.Terminate : 0,
	];
}


/// Returns: number of elements an instruction will pop from stack
/// 
/// Throws: Exception if wrong number of arguments provided
public uinteger instructionPopCount(Instruction inst, NaData[] arguments){
	if (arguments.length != INSTRUCTION_ARG_COUNT[inst])
		throw new Exception("wrong number of arguments provided for instruction");
	if (inst == Instruction.ExecuteFunction || inst == Instruction.ExecuteFunctionExternal){
		return arguments[1].intVal;
	}else if (inst == Instruction.MakeArray){
		return arguments[0].intVal;
	}
	return INSTRUCTION_POP_COUNT[inst];
}