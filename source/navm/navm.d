module navm.navm;


import std.conv : to;

import utils.ds;
import utils.misc;

public import navm.bytecode;

public alias NaInstruction = navm.bytecode.NaInst;
public alias readData = navm.bytecode.readData;

