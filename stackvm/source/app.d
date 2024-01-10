import std.stdio,
			 std.datetime.stopwatch,
			 std.traits,
			 std.meta,
			 std.conv : to;

import utils.misc;

import navm.navm;
import navm.bytecode;

struct Stack{
	ubyte[4096] stack;
	ushort seek;
	ushort base;
	pragma(inline, true) T pop(T)() if (!isArray!T){
		assert(seek >= T.sizeof, "Cannot pop `" ~ T.stringof ~ "` " ~ " seek is "
				~ seek.to!string);
		seek -= T.sizeof;
		return *(cast(T*)(stack.ptr + seek));
	}
	pragma(inline, true) T top(T)() if (!isArray!T){
		assert(seek >= T.sizeof, "Cannot pop `" ~ T.stringof ~ "` " ~ " seek is "
				~ seek.to!string);
		return *(cast(T*)(stack.ptr + seek - T.sizeof));
	}
	pragma(inline, true) void push(T)(T val) if (!isArray!T){
		assert(seek + T.sizeof <= stack.length, "Cannot push `" ~ T.stringof ~
				"` seek is " ~ seek.to!string);
		stack[seek .. seek + T.sizeof] = (cast(ubyte*)&val)[0 .. T.sizeof];
		seek += T.sizeof;
	}
}

///
unittest{
	Stack stack;
	stack.push(cast(ubyte)127);
	stack.push(cast(ubyte)128);
	stack.push(cast(ptrdiff_t)ptrdiff_t.max);
	assert(stack.pop!ptrdiff_t == ptrdiff_t.max);
	assert(stack.pop!ubyte == 128);
	assert(stack.pop!ubyte == 127);
}

static assert(float.sizeof == int.sizeof);

// math instructions

void addI(ref Stack _state){
	_state.push!int(_state.pop!int + _state.pop!int);
}

void subI(ref Stack _state){
	immutable int a = _state.pop!int;
	_state.push!int(a - _state.pop!int);
}

void mulI(ref Stack _state){
	_state.push!int(_state.pop!int * _state.pop!int);
}

void divI(ref Stack _state){
	immutable int a = _state.pop!int;
	_state.push!int(a / _state.pop!int);
}

void modI(ref Stack _state){
	immutable int a = _state.pop!int;
	_state.push!int(a % _state.pop!int);
}

void addF(ref Stack _state){
	_state.push!float(_state.pop!float + _state.pop!float);
}

void subF(ref Stack _state){
	immutable float a = _state.pop!float;
	_state.push!float(a - _state.pop!float);
}

void mulF(ref Stack _state){
	_state.push!float(_state.pop!float * _state.pop!float);
}

void divF(ref Stack _state){
	immutable float a = _state.pop!float;
	_state.push!float(a / _state.pop!float);
}

// comparison

void cmp(ref Stack _state){
	_state.push!int(_state.pop!int == _state.pop!int);
}

void lesI(ref Stack _state){
	immutable int a = _state.pop!int;
	_state.push!int(a < _state.pop!int);
}

void lesF(ref Stack _state){
	immutable float a = _state.pop!float;
	_state.push!int(a < _state.pop!float);
}

// boolean

void notB(ref Stack _state){
	_state.push!int(_state.pop!int == 0);
}

void andB(ref Stack _state){
	immutable int a = _state.pop!int, b = _state.pop!int;
	_state.push!int(a && b);
}

void orB(ref Stack _state){
	immutable int a = _state.pop!int, b = _state.pop!int;
	_state.push!int(a || b);
}

// bitwise

void not(ref Stack _state){
	_state.push!int(~(_state.pop!int));
}

void and(ref Stack _state){
	immutable int a = _state.pop!int, b = _state.pop!int;
	_state.push!int(a & b);
}

void or(ref Stack _state){
	immutable int a = _state.pop!int, b = _state.pop!int;
	_state.push!int(a | b);
}

// stack manipulation

void pshI(ref Stack _state, int val){
	_state.push!int(cast(int)val);
}

void pshF(ref Stack _state, float val){
	_state.push!float(val);
}

void pop(ref Stack _state){
	_state.seek -= int.sizeof;
}

void popN(ref Stack _state, int n){
	_state.seek -= int.sizeof * n;
}

void seek(ref Stack _state){
	_state.push!int(_state.top!int);
}

void off(ref Stack _state, int n){
	_state.base += n;
}

void off0(ref Stack _state){
	_state.base = 0;
}

void pshO(ref Stack _state){
	_state.push!int(_state.base);
}

void popO(ref Stack _state){
	_state.base = cast(ushort)_state.pop!int;
}

void get(ref Stack _state, int offset){
	_state.push!int(*(cast(int*)(_state.stack.ptr + _state.base + offset)));
}

void getR(ref Stack _state){
	immutable int offset = _state.pop!int;
	_state.push!int(_state.base + offset);
}

void put(ref Stack _state, int offset){
	*cast(int*)(_state.stack.ptr + _state.base + offset) = _state.pop!int;
}

void putR(ref Stack _state){
	immutable int val = _state.pop!int, addr = _state.pop!int;
	*cast(int*)(_state.stack.ptr + addr) = val;
}

void incA(ref Stack _state, int offset){
	int *ptr = cast(int*)(_state.stack.ptr + _state.base + offset);
	*ptr = *ptr + 1;
}

void incR(ref Stack _state){
	int *ptr = cast(int*)(_state.stack.ptr + _state.pop!int);
	*ptr = *ptr + 1;
}

// jumps

void jmp(ref size_t _ic, ref size_t _dc, ref Code _code, uint label){
	_ic = _code.labels[label][0];
	_dc = _code.labels[label][1];
}

void jmpC(ref size_t _ic, ref size_t _dc, ref Code _code, ref Stack _state,
		uint label){
	if (_state.pop!int != 0){
		_ic = _code.labels[label][0];
		_dc = _code.labels[label][1];
	}
}

void call(ref size_t _ic, ref size_t _dc, ref Code _code, ref Stack _state,
		uint label){
	_state.push!int(_state.base);
	_state.push!int(cast(int)_ic);
	_state.push!int(cast(int)_dc);
	_state.base = _state.seek;
	_ic = _code.labels[label][0];
	_dc = _code.labels[label][1];
}

void ret(ref size_t _ic, ref size_t _dc, ref Code _code, ref Stack _state){
	_dc = _state.pop!int;
	_ic = _state.pop!int;
	_state.base = cast(ushort)_state.pop!int;
}

void dbg(ref Stack _state){
	writefln!"base: %d\tseek: %d"(_state.base, _state.seek);
}

void printI(ref Stack _state){
	write(_state.pop!int);
}

void printF(ref Stack _state){
	write(_state.pop!float);
}

void printS(string s){
	write(s);
}

alias InstructionSet = AliasSeq!(addI, subI, mulI, divI, modI, addF, subF,
		mulF, divF, cmp, lesI, lesF, notB, andB, orB, not, and, or, pshI, pshF,
		pop, popN, seek, off, pshO, popO, off0, get, getR, put, putR, incA, incR,
		jmp, jmpC, call, ret, dbg, printI, printF, printS);

void main(string[] args){
	if (args.length < 2)
		args = [args[0], "tests/default"];
	immutable size_t count = args.length > 2 && args[2].isNum
		? args[2].to!size_t : 1;
	StopWatch sw;
	PICode picode = parseByteCode!InstructionSet(fileToArray(args[1]));
	// TODO prepare bytecode
	Code code = picode._code;
	debug {
		writeln("Code: ");
		writeln(code);
	}

	Stack state;
	immutable ptrdiff_t startIndex = code.labelNames.indexOf("start");
	if (startIndex == -1){
		writeln("label `start` not found");
		return;
	}

	size_t min = size_t.max ,max = 0 ,avg = 0;
	sw = StopWatch(AutoStart.no);
	foreach (i; 0 .. count){
		state = Stack.init;
		sw.start;
		execute!(Stack, InstructionSet)(code, state, startIndex);
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
