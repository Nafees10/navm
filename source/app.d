import std.stdio;
import navm.navm;

import utils.misc : fileToArray;
import std.datetime.stopwatch;


void main(string[] args){
	NaData writelnInt(NaData[] args){
		foreach(arg; args){
			write(arg.intVal);
		}
		write('\n');
		return NaData();
	}
	NaData writelnDbl(NaData[] args){
		foreach (arg; args){
			write(arg.doubleVal);
		}
		write('\n');
		return NaData();
	}
	NaVM vm = new NaVM([&writelnInt, &writelnDbl]);
	vm.load(fileToArray(args[1]));
	StopWatch sw;
	sw.start;
	vm.execute(0, []);
	sw.stop;
	writeln("Execution took: ",sw.peek.total!"msecs", " msecs");
}
