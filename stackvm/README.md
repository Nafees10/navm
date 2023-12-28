# StackVM

A Demo VM built using NaVM.

## Instructions

### Arithmetic

* `addI` - pushes sum of top 2 integers
* `subI` - pops a, b integers. Pushes a - b
* `mulI` - pushes product of top 2 integers
* `divI` - pops a, b integers. Pushes a / b
* `modI` - pops a, b integers. Pushes a % b
* `addF` - pushes sum of top 2 floats
* `subF` - pops a, b floats. Pushes a - b
* `mulF` - pushes product of top 2 floats
* `divF` - pops a, b floats. Pushes a / b

### Comparison

* `cmp` - Compares top 2 32bit values. Pushes 1 (integer) if same, else 0
* `lesI` - Pops a, b integers. Pushes 1 (integer) if a < b, else 0
* `lesF` - Pops a, b floats. Pushes 1 (integer) if a < b, else 0
* `notB` - Pushes 1 (integer) if top integer is 0, else 0
* `andB` - Pushes 1 (integer) if top 2 integers are non-zero, else 0
* `orB` - Pushes 1 (integer) if either of top 2 integers are non-zero, else 0

### Bitwise

* `not` - Pushes NOT of top integer
* `and` - Pushes AND of top 2 integers
* `or` - Pushes OR of top 2 integers

### Stack manipulation

* `pshI a` - Pushes integer `a`
* `pshF a` - Pushes float `a`
* `pop` - Pops 1 integer/float
* `popN n` - Pops `n` integers/floats
* `off n` - Adds `n` to stack read/write offset
* `off0` - Sets stack read/write offset to 0
* `pshO` - pushes stack offset
* `popO` - Pops integer, sets it as stack offset
* `get n` - Pushes 32 bits from `offset + n`
* `getR n` - Pushes address of `offset + n`
* `put n` - Pops 32 bit value. Writes to `offset + n`
* `putR` - Pops a 32 bit value, address. Writes value to stack at address.

### Jumps

* `jmp label` - Jumps execution to label
* `jmpC label` - Jumps execution to label, if top integer is non-zero.
* `call labal` - Pushes stack offset, `_ic`, and `_dc`, sets offset to top,
	and jumps to label
* `ret` - pops `_dc`, `_ic`, and stack offset and sets them.

### Printing

* `printI` - Prints top integer popped from stack
* `printF` - Prints top float popped from stack
* `printS s` - Prints the string `s`
