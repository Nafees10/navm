module navm.bytecode;

import utils.misc;
import utils.lists;

import navm.defs;

/// stores an instruction
enum Instruction : ubyte{
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

	isSameInt = 0x07,/// if both values are same (integer)
	isSameArrayInt = 0x08, /// if 2 int[] have same values
	isLesserInt = 0x09,/// is val0 < val1 (integer)
	isLesserSameInt = 0x0A,/// if val1 <= val2 (integer)

	isSameDouble = 0x17,/// if both values are same (double)
	isSameArrayDouble = 0x18, /// if 2 double[] have same values
	isLesserDouble = 0x19,/// is val0 < val1 (double)
	isLesserSameDouble = 0x1A,/// if val1 <= val2 (double)

	BinaryNot = 0x20,/// not operator (integer)
	BinaryAnd = 0x21,/// and operator (integer)
	BinaryOr = 0x22,/// or operator (integer)

	Push = 0x30,/// pushes one value to stack
	PushFrom = 0x31,/// Writes pop-ed data to an-index-N on stack
	PushTo = 0x32, /// Pops a value from stack, writes it to an index on stack
	Pop = 0x33,/// Pops one value from stack
	Jump = 0x34, /// jumps to instruction at index N
	JumpIf = 0x35, /// jump but checks if value pop-ed from stack == 1 before jumping

	MakeArray = 0x40, /// pushes array with N number of elemets, read from stack
	ReadElement = 0x41, /// Pushes ref-to-element-in-array-at-index-poped-from-stack to stack
	ArrayLength = 0x42, /// Pushes length of array to stack, array pop-ed from stack
	ArrayLengthSet = 0x43, /// Changes length of array pop-ef from stack to new length, pop-ed from stack
	Concatenate = 0x44,/// Concatenate arrays
	Append = 0x45, /// Appends an element at end of array, pushes new array

	IntToDouble = 0x50,/// pushes doulbe with the same value as int poped from stack
	DoubleToInt = 0x51,/// pushes int with same integer value as double poped from stack
}

/// stores number of arguments an instruction needs
static ubyte[Instruction] INSTRUCTION_ARG_COUNT;


/// stores how many elements an instruction will push to stack
static ubyte[Instruction] INSTRUCTION_PUSH_COUNT;

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

		Instruction.isSameInt : 0,
		Instruction.isSameArrayInt : 0,
		Instruction.isLesserInt : 0,
		Instruction.isLesserSameInt : 0,

		Instruction.isSameDouble : 0,
		Instruction.isSameArrayDouble : 0,
		Instruction.isLesserDouble : 0,
		Instruction.isLesserSameDouble : 0,

		Instruction.BinaryAnd : 0,
		Instruction.BinaryNot : 0,
		Instruction.BinaryOr : 0,

		Instruction.Push : 1,
		Instruction.PushFrom : 1,
		Instruction.PushTo : 1,
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

		Instruction.isSameInt : 1,
		Instruction.isSameArrayInt : 1,
		Instruction.isLesserInt : 1,
		Instruction.isLesserSameInt : 1,

		Instruction.isSameDouble : 1,
		Instruction.isSameArrayDouble : 1,
		Instruction.isLesserDouble : 1,
		Instruction.isLesserSameDouble : 1,

		Instruction.BinaryAnd : 1,
		Instruction.BinaryNot : 1,
		Instruction.BinaryOr : 1,

		Instruction.Push : 1,
		Instruction.PushFrom : 1,
		Instruction.PushTo : 0,
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

		Instruction.isSameInt : 2,
		Instruction.isSameArrayInt : 2,
		Instruction.isLesserInt : 2,
		Instruction.isLesserSameInt : 2,

		Instruction.isSameDouble : 2,
		Instruction.isSameArrayDouble : 2,
		Instruction.isLesserDouble : 2,
		Instruction.isLesserSameDouble : 2,

		Instruction.BinaryAnd : 2,
		Instruction.BinaryNot : 2,
		Instruction.BinaryOr : 2,

		Instruction.Push : 0,
		Instruction.PushFrom : 0,
		Instruction.PushTo : 1,
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
	];
}


/// Returns: number of elements an instruction will pop from stack
/// 
/// Throws: Exception if wrong number of arguments provided
uinteger instructionPopCount(Instruction inst, RuntimeData[] arguments){
	if (arguments.length != INSTRUCTION_ARG_COUNT[inst])
		throw new Exception("wrong number of arguments provided for instruction");
	if (inst == Instruction.ExecuteFunction || inst == Instruction.ExecuteFunctionExternal){
		return arguments[1].intVal;
	}else if (inst == Instruction.MakeArray){
		return arguments[0].intVal;
	}
	return INSTRUCTION_POP_COUNT[inst];
}