import std.stdio,
			 std.datetime.stopwatch,
			 std.traits,
			 std.meta,
			 std.conv : to;

import utils.misc;

import navm.navm;
import navm.bytecode;

enum Bar;

struct State{
	ubyte[4096] stack;
	ushort stackSeek;
}

void jump(ref size_t _ic, ref size_t _dc, ref ByteCode _code, size_t label){
	_ic = _code.labels[label][0];
	_dc = _code.labels[label][1];
}

// TODO add more instructions


alias InstructionSet = AliasSeq!();

void main(string[] args){
	if (args.length < 2)
		args = [args[0], "tests/default"];
	immutable size_t count = args.length > 2 && args[2].isNum
		? args[2].to!size_t : 1;
	StopWatch sw;
	ByteCode code = parseByteCode!InstructionSet(fileToArray(args[1]));

	State state;
	immutable ptrdiff_t startIndex = code.labelNames.indexOf("start");
	if (startIndex == -1){
		writeln("label `start` not found");
		return;
	}

	size_t min = size_t.max ,max = 0 ,avg = 0;
	sw = StopWatch(AutoStart.no);
	foreach (i; 0 .. count){
		sw.start;
		execute!(State, InstructionSet)(code, state, startIndex);
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
