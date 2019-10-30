import std.stdio;
import navm.navm;

import utils.misc;
import std.datetime.stopwatch;


void main(string[] args){
	debug{
		args = [args[0] , "sample"];
	}
	NaData writelnInt(NaData[] args){
		foreach(arg; args){
			write(arg.intVal);
		}
		write('\n');
		return NaData();
	}
	NaVM vm = new NaVM([&writelnInt]);
	vm.load(fileToArray(args[1]));
	StopWatch sw;
	sw.start;
	vm.execute(0, []);
	sw.stop;
	writeln("Execution took: ",sw.peek.total!"msecs", " msecs");
}
