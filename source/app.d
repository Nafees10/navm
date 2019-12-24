import std.stdio;
import navm.navm;

import utils.misc;
import std.datetime.stopwatch;

import core.memory : GC;


void main(string[] args){
	//GC.disable();
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
	NaData writelnIntArray(NaData[] args){
		NaData[] array = args[0].arrayVal;
		for (uinteger i = 0; i < array.length; i++){
			writeln(array[i].intVal);
		}
		return NaData();
	}
	NaData writelnStr(NaData[] args){
		foreach (arg; args){
			write(arg.strVal);
		}
		write('\n');
		return NaData();
	}
	NaVM vm = new NaVM([&writelnInt, &writelnStr, &writelnIntArray]);
	vm.load(fileToArray(args[1]));
	StopWatch sw;
	sw.start;
	vm.execute(0, []);
	sw.stop;
	writeln("Execution took: ",sw.peek.total!"msecs", " msecs");
}
