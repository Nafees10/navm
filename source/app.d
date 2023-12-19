version(demo){
	import std.stdio,
				 std.datetime.stopwatch,
				 std.traits,
				 std.conv : to;

	import std.meta;

	import navm.navm;

	enum Bar;

	class Stack : Shared{
	public:
		ptrdiff_t[512] stack;
		size_t seek;
	}

	pragma(inline, true) void push(Stack stack, ptrdiff_t i){
		writefln!"pushing %d"(i);
		stack.stack[stack.seek ++] = i;
	}
	pragma(inline, true) void pop(Stack stack){
		stack.seek --;
		writefln!"popped %d"(stack.stack[stack.seek]);
	}
	pragma(inline, true) void jump(size_t* _ic, size_t* _dc, ByteCode code,
			string label){
		*_ic = code.labels[label][0];
		*_dc = code.labels[label][1];
	}

	alias InstructionSet = AliasSeq!(push, pop, jump);

	void main(string[] args){
		Stack stack = new Stack;
		string[] source = [
			"start:",
			"push 50",
			"push 100",
			"pop",
			"pop",
			"jump \"start\""
		];
		ByteCode code = parseByteCode!(InstructionSet)(source);
		writeln(code);
		execute!(InstructionSet)(code, stack, "start");
	}
}
