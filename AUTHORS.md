Authors:
Lyudmila Kaneva ldk66
Anthony Querbach aq63
Adrian Hung ah2427
Artyom Jhangiryan aj682
Armen Amirbekian aaa462

Claude and other AI agents helped significantly


for adding libraries:

Adding other libraries
If an assignment asks you to add a library, you will need to put the library's name into the "dune" file in the appropriate directory — "bin/dune", or "lib/dune", or "test/dune" — depending on which parts of your codebase need to use the library. For example, if your main program in "bin/main.ml" needs to use the ANSITerminal library, you would modify "bin/dune" like this (where the ellipses indicate some additional code that is omitted here):

(executable (public_name ...) (name ...) (libraries ... ANSITerminal))

Or if your code in "lib" needs to use the Batteries library, you would modify "lib/dune" like this (where the ellipses indicate some additional code that is omitted here):

(library (name ...) (libraries batteries ...))