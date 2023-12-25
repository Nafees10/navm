version(demo){
	import std.stdio,
				 std.datetime.stopwatch,
				 std.traits,
				 std.meta,
				 std.conv : to;

	import utils.misc;

	import navm.navm;
	import navm.bytecode;

	enum Bar;

	struct Store{
		ptrdiff_t[512] stack;
		size_t stackSeek;
		ptrdiff_t reg;
		bool cmp;
	}

	pragma(inline, true) void store(ref Store _state, ptrdiff_t val){
		_state.reg = val;
	}

	pragma(inline, true) void load(ref Store _state, ref ByteCode _code,
			ptrdiff_t addr){
		_state.reg = _code.data[addr .. $].as!ptrdiff_t;
	}

	pragma(inline, true) void add(ref Store _state, ptrdiff_t val){
		_state.reg += val;
	}

	pragma(inline, true) void cmp(ref Store _state, ptrdiff_t val){
		_state.cmp = val == _state.reg;
	}

	pragma(inline, true) void print(ref Store _state){
		writeln(_state.reg);
	}

	pragma(inline, true) void jumpIf(ref Store _state, ref ByteCode _code,
			ref size_t _ic, ref size_t _dc, size_t label){
		if (!_state.cmp)
			return;
		_ic = _code.labels[label][0];
		_dc = _code.labels[label][1];
	}

	pragma(inline, true) void jump(ref size_t _ic, ref size_t _dc,
			ref ByteCode code, size_t label){
		_ic = code.labels[label][0];
		_dc = code.labels[label][1];
	}

	pragma(inline, true) void push(ref Store _state){
		_state.stack[_state.stackSeek ++] = _state.reg;
	}

	pragma(inline, true) void pop(ref Store _state){
		_state.reg = _state.stack[-- _state.stackSeek];
	}

	alias InstructionSet = AliasSeq!(store, load, add, cmp, print, jumpIf, jump,
			push, pop);

	void main(string[] args){
		if (args.length < 2)
			args = [args[0], "tests/default"];
		immutable size_t count = args.length > 2 && args[2].isNum
			? args[2].to!size_t : 1;
		StopWatch sw;
		ByteCode code = parseByteCode!InstructionSet(fileToArray(args[1]));
		//writeln(code);

		Store store;
		immutable ptrdiff_t startIndex = code.labelNames.indexOf("start");
		if (startIndex == -1){
			writeln("label `start` not found");
			return;
		}

		size_t min = size_t.max ,max = 0 ,avg = 0;
		sw = StopWatch(AutoStart.no);
		foreach (i; 0 .. count){
			sw.start;
			execute!(Store, InstructionSet)(code, store, startIndex);
			sw.stop;
			immutable size_t currentTime = sw.peek.total!"msecs" - avg;
			min = currentTime < min ? currentTime : min;
			max = currentTime > max ? currentTime : max;
			avg = sw.peek.total!"msecs";
		}
		avg = sw.peek.total!"msecs" / count;

		writeln("executed `",args[1],"` ",count," times:");
		writeln("min\tmax\tavg\ttotal");
		writeln(min,'\t',max,'\t',avg,'\t',sw.peek.total!"msecs");
	}
}
