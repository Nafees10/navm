version(demo){
	import std.stdio,
				 std.datetime.stopwatch,
				 std.traits,
				 std.conv : to;

	import std.meta;

	import navm.navm;

	enum Bar;

	class Stack{
	public:
		ptrdiff_t[512] stack;
		size_t seek;
	}

	pragma(inline, true) void push(Stack _state, ptrdiff_t i){
		writefln!"pushing %d"(i);
		_state.stack[_state.seek ++] = i;
	}
	pragma(inline, true) void pop(Stack _state){
		_state.seek --;
		writefln!"popped %d"(_state.stack[_state.seek]);
	}
	pragma(inline, true) void jump(ref size_t _ic, ref size_t _dc,
			ref ByteCode code, size_t label){
		_ic = code.labels[label][0];
		_dc = code.labels[label][1];
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
			"jump @start"
		];
		ByteCode code = parseByteCode!(InstructionSet)(source);
		writeln(code);
		execute!(Stack, InstructionSet)(code, stack, code.labelNames["start"]);
	}
}
