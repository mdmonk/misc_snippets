#!/cygdrive/d/Perl/bin/perl

$VERSION = "0.21";

# pod documentation is at the bottom

use strict;
use Getopt::Std;

my @commands;        # program segment: data and instructions
my %symbols;         # symbol table: keys are labels values are command numbers
my $progpointer = 0; # program pointer, the number of the current command
my @ppstack;         # stack to save program pointers during gosub calls
my $com_no = 0;      # commands array index while reading input
my $comm;            # stores the subroutine to be called while reading input
my @tmp;             # holds input line without label split on whitespace
my $evalable;        # code to be executed via eval, stored in commands
my $i;               # loop counter for alloc directive (counts slots reserved)
my $resume_lab;      # label at which debugging will resume (set in sub debug)
my %revsymbols;      # symbol table reversed for printing routines
my $tracing = 0;     # flag.  true if we're tracing, false otherwise
my @callstack;       # where the user can store params for gosubs and returns

getopts('lst');      # l - listing only; s - single step; t - trace

# The following while loop reads the user input file.
while (<>) {
  next if (/^#/);
  next if (/^\s*$/);
  chomp;
  if (s/^              # at the beginning of the line
        \s*            # get optional leading whitespace
	([a-zA-Z]\S*)  # capture identifier
	\s*            # get optional trailing whitespace
	:              # literal colon
       //x             # if this matches, remove it
  ) {
    $symbols{$1} = $com_no;
  }
  elsif (/:/) {
    chomp;
    die "Invalid command label at line $.:\n$_\n";
  }
  (@tmp) = split;
  $comm = $tmp[0];
  if ($comm eq "alloc") { # don't store command, save space
    if ($tmp[1] < 1) {
      chomp;
      die "alloc requires a positive operand at line $.:\n$_\n";
    }
    for ($i = 0; $i < $tmp[1]; $i++) {
      $commands[$com_no+$i] = 0;
    }
    $progpointer += $tmp[1] if ($progpointer == $com_no);
    $com_no += $tmp[1];
    next;
  }
  if ($comm eq "prompt") { # don't split argument
    s/\s*$comm\s*//;
    $evalable = "prompt($_)";
  }
  else { # regular command {
    $evalable = shift(@tmp) . "('" . join("', '", @tmp) . "');";
  }
  $commands[$com_no++] = $evalable;
}

%revsymbols = reverse %symbols;

if (defined $Getopt::Std::opt_l) {
  shower();
  exit 0;
}

if (defined $Getopt::Std::opt_t) { $tracing = 1; }

# The following while loop interprets the user's program.
# It will allow the user the joy of an infinite loop.
while (1) {
  if ($tracing) {
    print "about to exec: ";
    _showline($progpointer);
    print "\n" unless ($Getopt::Std::opt_s);
  }
  debug() if ($Getopt::Std::opt_s);

  if ($commands[$progpointer]) {
    eval $commands[$progpointer];
    if ($@ =~ /^Undefined subroutine.*::(\S+)\s/) {
      bailout("No such PAL command: $1 at line $progpointer");
    }
    die $@ if $@;
  }
  else {
    die "Program pointer has moved to undefined command $progpointer.\n";
  }
  $progpointer++;  # these lines can't be combined, commands can change the ptr
}

sub debug {
# debug is called before each command is executed if and only if the
# user requested single stepping on the command line with -s
# 
# the commands in trace mode are:
# return - step to next command
# show var - print the value of var (not subject to addressing modes)
# shower - shows program segment and program pointer
# go - turns off tracing and single stepping
# go lab - turns off tracing and single stepping until lab is reached
# q - stop execution immediately

  my $cur_lab = $revsymbols{$progpointer};
  my $debug_in;
  my $show_var;

  if (defined $resume_lab) {
    if (defined $cur_lab) {
      if ($cur_lab eq $resume_lab) {
	print "Execution is about to execute desired label $resume_lab\n";
        $resume_lab = undef;
	$tracing = 1 if $Getopt::Std::opt_t;
      }
      else {
	return;
      }
    }
    else {
      return;
    }
  }

  DEBUG: {
    print " ";
    $debug_in = <STDIN>;
    exit(0) if ($debug_in =~ /^[qQ]/);
    if ($debug_in =~ /show\s+([a-zA-Z].*)\s*/) {
      $show_var = $1;
      print "$show_var = $commands[$symbols{$show_var}] \n";
      redo DEBUG;
    }
    if ($debug_in =~ /go\s*([a-zA-Z].*)\s*/) {
      $resume_lab = $1;
      $tracing = 0;
    }
    elsif ($debug_in =~ /go/) {
      $Getopt::Std::opt_s = undef;
      $tracing = 0;
    }
    shower() if ($debug_in =~ /shower/i);
  }
}

sub take {
  my $loc = shift;
  my $in;

  chomp($in = <STDIN>);
  _massageloc($loc, "store", $in);
}

sub prompt {
  print "@_";
}

sub add {
  my ($val, $loc) = @_;
  my $actual_val = _massageloc($val, "retrieve");

  _massageloc($loc, "add", $actual_val);
}

sub subt {
  my ($val, $loc) = @_;
  my $actual_val = _massageloc($val, "retrieve");

  _massageloc($loc, "subtract", $actual_val);
}

sub mult {
  my ($val, $loc) = @_;
  my $actual_val = _massageloc($val, "retrieve");

  _massageloc($loc, "multiply", $actual_val);
}

sub div {
  my ($val, $loc) = @_;
  my $actual_val = _massageloc($val, "retrieve");

  _massageloc($loc, "divide", $actual_val);
}

sub pushop {
  my $source = shift;
  my $value  = _massageloc($source, "retrieve");

  push @callstack, $value;
}

sub popop {
  my $destination = shift;

  my $value = pop @callstack;

  _massageloc($destination, "store", $value);
}

sub prt {
  my (@vars)  = @_;
  my $var;
  my $val;

  foreach $var (@vars) {
    $val = _massageloc($var, "retrieve");
    print $val . " ";
  }
  print "\n";
}

sub ret {
  my $oldptr = $progpointer;
  $progpointer = pop @ppstack;

  die "Attempt to return without prior gosub at command $oldptr\n"
    unless $progpointer;
}

sub gosub {
  my $branch_name = shift;
  my $branch = $symbols{$branch_name};

  unless ($branch) {
    bailout("Invalid gosub label: '$branch_name' in command $progpointer");
  }

  push @ppstack, $progpointer;
  $progpointer = $branch - 1;
}

sub end {
  my ($status) = shift;
  $status = 0 unless $status;

  exit $status;
}

sub brlt {
  my ($it1, $it2, $branch_name) = @_;
  my $branch;

  if (_massageloc($it1, "retrieve") < _massageloc($it2, "retrieve")) {
    $branch = $symbols{$branch_name};

    unless ($branch) {
      bailout("Invalid label: '$branch_name' to brlt in command $progpointer");
    }
    $progpointer = $branch - 1;
  }
}

sub brle {
  my ($it1, $it2, $branch_name) = @_;
  my $branch;

  if (_massageloc($it1, "retrieve") <= _massageloc($it2, "retrieve")) {
    $branch = $symbols{$branch_name};

    unless ($branch) {
      bailout("Invalid label: '$branch_name' to brle in command $progpointer");
    }
    $progpointer = $branch - 1;
  }
}

sub brgt {
  my ($it1, $it2, $branch_name) = @_;
  my $branch;

  if (_massageloc($it1, "retrieve") > _massageloc($it2, "retrieve")) {
    $branch = $symbols{$branch_name};

    unless ($branch) {
      bailout("Invalid label: '$branch_name' to brgt in command $progpointer");
    }
    $progpointer = $branch - 1;
  }
}

sub brge {
  my ($it1, $it2, $branch_name) = @_;
  my $branch;

  if (_massageloc($it1, "retrieve") >= _massageloc($it2, "retrieve")) {
    $branch = $symbols{$branch_name};

    unless ($branch) {
      bailout("Invalid label: '$branch_name' to brge in command $progpointer");
    }
    $progpointer = $branch - 1;
  }
}

sub breq {
  my ($it1, $it2, $branch_name) = @_;
  my $branch;

  if (_massageloc($it1, "retrieve") == _massageloc($it2, "retrieve")) {
    $branch = $symbols{$branch_name};

    unless ($branch) {
      bailout("Invalid label: '$branch_name' to breq in command $progpointer");
    }
    $progpointer = $branch - 1;
  }
}

sub brne {
  my ($it1, $it2, $branch_name) = @_;
  my $branch;

  if (_massageloc($it1, "retrieve") != _massageloc($it2, "retrieve")) {
    $branch = $symbols{$branch_name};

    unless ($branch) {
      bailout("Invalid label: '$branch_name' to brne in command $progpointer");
    }
    $progpointer = $branch - 1;
  }
}

sub jump {
  my $branch_name = shift;
  my $branch = $symbols{$branch_name};

  unless ($branch) {
    bailout("Invalid jump label: '$branch_name' in command $progpointer");
  }

  $progpointer = $branch - 1;
}

# These deprecated routines have finally been removed to make room for
# pushop and popop.  There are still 21 statements and 1 directive.
#
#sub incr {
#  my ($nam) = @_;
#
#  _massageloc($nam, "incr");
#}
#
#sub decr {
#  my ($nam) = @_;
#
#  _massageloc($nam, "decr");
#}

sub store {
  my ($val, $loc) = @_;
  my $actual_val = _massageloc($val, "retrieve");
  _massageloc($loc, "store", $actual_val);
}

sub _showline {
# _showline is an internal function which takes a command number and
# prints the command or data stored under that number.  The output
# is massaged so that it looks roughly like the source file rather
# than the evalable Perl form stored in the commands array.
#
  my $commno = shift;
  my $tmpcom;

  printf("%4d ", $commno);
  if (defined $revsymbols{$commno}) {
    print("$revsymbols{$commno}: ");
  }
  else {
    print "    ";
  }
  $tmpcom = $commands[$commno];
  $tmpcom =~ s/[),';]//g;
  $tmpcom =~ s/[(]/ /;
  print "\t$tmpcom";
}

sub shower {
  my $tmpcom;
  my $commno;
  my $i;

  for ($i = 0; $i < @commands; $i++) {
    _showline($i);
    print "\n";
  }
  print "The current program pointer is $progpointer\n";
}

sub _mode {
# Takes the user supplied operand and decodes its addressing mode.
# The name of the initial storage location is placed into the second
# argument to _mode which should be a reference to a scalar.
# RETURNS: name of $operand's addressing mode.

  my $operand = shift;
  my $basename = shift;
  my $work = $operand;  # copy of user's operand so we don't hurt input
  my $ret_val;          # string with name of addressing mode

  if ($work =~ /^\d/) {
    $$basename = $work;
    return "literal";
  }
  elsif ($work =~ s/^@@//) {
    $ret_val = "double_indirect";
  }
  elsif ($work =~ s/^@//) {
    $ret_val = "indirect";
  }
  elsif ($work =~ s/^&//) {
    $$basename = $work;
    return "addressof";
  }
  else {
    $$basename = $work;
    return "direct";
  }
  if ($work =~ s/^\+//) {
    $ret_val .= " pre increment";
  }
  elsif ($work =~ s/^-//) {
    $ret_val .= " pre decrement";
  }
  elsif ($work =~ s/\+$//) {
    $ret_val .= " post increment";
  }
  elsif ($work =~ s/-$//) {
    $ret_val .= " post decrement";
  }
  $$basename = $work;
  return $ret_val;
}

sub _massageloc {
# retrieves the value referred to by operand
# stores the value in the location pointed to by operand
# or performs math on the value in the location pointed to by operand
# in all cases:
# increments/decrements properly
#
# the addressing mode is determine by a call to _mode
#
# This routine should be split in two since one block is already repeated
# and would appear a third time if double indirect modes were in use.

  my $operand = shift;
  my $operation = shift;
  my $input = shift;
  my $loc;
  my $mode;
  my $nam;
  my $init_val;
  my $val;

  $mode = _mode($operand, \$nam);
  if ($mode eq "literal") {
    return $nam;
  }
  $loc = $symbols{$nam};
  if (not defined $loc) {
    bailout("Attempt to use address mode on undeclared" .
      " identifier '$nam' at command $progpointer");
  }
  $init_val = $commands[$loc];  # could be undefined, might or might not be bad
  
  if ($mode eq "direct") {
    if ($operation eq "retrieve") {
      return $init_val;
    }
    elsif ($operation eq "store") {
      $commands[$loc] = $input;
    }
    elsif ($operation eq "add") {
      $commands[$loc] += $input;
    }
    elsif ($operation eq "subtract") {
      $commands[$loc] -= $input;
    }
    elsif ($operation eq "multiply") {
      $commands[$loc] *= $input;
    }
    elsif ($operation eq "divide") {
      $commands[$loc] /= $input;
    }
    else {
      die "Illegal call to private funtion _massageloc, " .
          "can't perform '$operation'\n";
    }
    return;
  }
  if ($mode eq "addressof") {
    if ($operation eq "retrieve") {
      return $loc;     
    }
    else {
      bailout(
        "Address of operorator not allowed for '$nam' at command $progpointer");
    }
  }
  if ($mode =~ s/indirect ?//) {
    if ($mode =~ s/pre //) {
      if ($mode eq "increment") {
        $commands[$symbols{$nam}] = ++$init_val;
      }
      else {
        $commands[$symbols{$nam}] = --$init_val;
      }
    } # end of pre
    if ($operation eq "retrieve") {
      $val = $commands[$init_val];
      if (not defined $val) {
        bailout(
	  "Bad indirect pointer '$nam=$init_val' at command $progpointer");
      }
    }
    elsif ($operation eq "store") {
      $commands[$init_val] = $input;
    }
    elsif ($operation eq "add") {
      $commands[$init_val] += $input;
    }
    elsif ($operation eq "subtract") {
      $commands[$init_val] -= $input;
    }
    elsif ($operation eq "multiply") {
      $commands[$init_val] *= $input;
    }
    elsif ($operation eq "divide") {
      $commands[$init_val] /= $input;
    }
    else {
      die "Illegal call to private funtion _massageloc, " .
          "can't perform '$operation'\n";
    }
    if ($mode =~ s/post //) {
      if ($mode eq "increment") {
        $commands[$symbols{$nam}] = ++$init_val;
      }
      else {
        $commands[$symbols{$nam}] = --$init_val;
      }
    } # end of post
    if ($operation eq "retrieve") {return $val;}
  } # end of indirect
} # end of _massageloc routine

sub bailout {
  my $message = shift;
  print STDERR "$message:\n";
  _showline($progpointer);
  die "\n";
}

=head1 NAME

assembly - an assembly language simulator

=head1 README

Simulates an assembly language with 21 statements and 1 assembler
directive.  Allows teachers to introduce assembly without having to
tie themselves to a processor or spend an entire school term.  The language
is simple, use it in class to teach the basic ideas of calculation,
arrays, recursion, etc.  Use it as a device independent destination for
student built compilers.

=head1 DESCRIPTION

B<assembly> implements the Pseudo-Assembly Language (PAL) in Perl.
PAL is modeled after Macro-11, but it is highly reduced.  There are only
22 commands (one of which is an assembly directive).  Addressing modes
are available but only with single indirection (see addressing modes below
for details).

The goal of PAL and this script is to teach students a bit about assembly
without having to learn a full blown assembler.  This allows for a short
introduction.  Further, since PAL is implemented in Perl, it is device
independent, freeing the instructor and student to pursue it without
regard to the underlying hardware.

This PAL interpretter also provides a destination for simple compilers.
I originally wrote it so I could complete a compiler for a simple language
of my own design as I worked through the Dragon Book.  Having a PAL
interpretter meant that I could compile all the way to an assembly, which
was the same on an HP 9000 and an Intel Pentium.  This exercise could
be repeated with students, though I haven't tried it.

=head1 USAGE

 assembly [-lst] [file...]

B<assembly> must receive a Pseudo-Assembly Language (PAL) file as a command
line argument or on standard input (do not place the source file on
standard input if you use the take command or the s or t options).
It interprets the file(s) as one program to standard out.

Each line in a PAL input file has one of the following forms:

 # comment

or

 label:  command  operand1  operand2 ...

Comments begin with a pound sign (#) in the first column.
Blank lines are also allowed.  Comments and blank lines are ignored.

The label is optional.  If the label is present the colon is required, if
absent the colon cannot appear.  Labels begin with a letter and
may not contain whitespace.  Trailing whitespace before the colon
is allowed and ignored if present.

The valid commands of PAL are listed below.  Note that, except
for the colon and string quotes, whitespace is the only punctuation.

Most operands are subject to symbol table lookup and addressing
modes.  See the addressing modes section below for the exceptions.

=head2 OPTIONS

The command line options request various debugging features.

=over 4

=item -l

provides a listing of the program before the first statement
is executed and immediately exits.  The program is not run.

=item -t

provides a trace of all commands being executed.  As with option s, this
mode precludes putting the source code on standard input.

=item -s

provides single stepping through commands, often used with option t.
If this option is used, the source code cannot be placed on standard input,
since that is where the single step mode gets its commands.
While in single stepping mode the following commands are available:

=over 8

=item carriage return -

steps to the next command.

=item go -

turns off tracing and single stepping, allowing execution to procede
as normal.

=item go lab -

turns off tracing and single stepping until a command with
label lab is reached.  If lab is not in the symbol table, go lab is
equivalent to go.

=item q (or Q or quit etc.) -

stops execution immediately.

=item show var -

prints the value of the specified variable which must
be in the symbol table.

=item shower -

prints a current listing of the program segment, as if the shower
command appeared at that point of the source code.

=back

=back

=head1 COMMANDS in PAL

=over 5

=item add

adds its first operand to its second operand storing
the result in the second operand.

=item alloc

an assembler directive to set aside operand slots in the
program segment.  Operand must be a positive integer, floating
point values may cause unpredictable results.  Slots are
initialized to zero.  Allocation is at assembly time and thus
cannot be dynamic.

=item brxx

compares its first two operands and branches to the label in
its third operand if its test is valid.  The last two letters
indicate the test operation:

 lt - less than
 le - less than or equal to
 gt - greater than
 ge - greater than or equal to
 eq - equal to
 ne - not equal to

For example:

 brlt i 5 label

will go to label when the value in the location labeled i is
less than 5, otherwise execution will fall to the next command.

=item div

divides its first operand into its second operand and
stores the result in its second operand.

=item end

halts execution and returns its operand as the exit status of
B<assembly>.  The operand will be returned as a literal, it will not be
looked up in the symbol table.  Returns 0 exit status by default.

=item jump

goes to the label given as its operand.

=item gosub

pushes the current program pointer onto the stack and goes to
the label given as its operand.  Note that parameter passing via a stack
is not supported.

=item mult

multiplies its first operand by its second operand
and stores the result in its second operand.

=item popop

retrieves a value previously pushed onto the internal stack.
To put values there, use pushop.  If the value was put on with &name,
you must use @ to follow the pointer to its value.
Note that the stack involved here is NOT related to the program pointer
stack which is managed internally so ret commands know where to return to.

=item prompt

prints the string given as its one operand.  The string must
appear in double quotes.  New lines and other such special characters
are specified as in C/Java/Perl and company.  For example \n is newline.

=item prt

prints the value of each operand.  Output formating is not
supported.  The values of the arguments are printed on the same
line, with spaces between them, in the full precision of Perl.  Text can
be added after a fashion with the prompt command (see the second
example below).

=item pushop

pushes its only operand onto the internal stack.  To retrieve,
use popop.  The operand is subject to addressing modes.  In particular
this means that you can have pass a reference if you use &var_name
(think C programming here).  Then the recipient must use @ to dereference
the pointer you put there.  (C programmers would use * for the dereference.)
Note that the stack involved here is NOT related to the program pointer
stack which is managed internally so ret commands know where to return to.

=item ret

pops the program pointer stored by a previous gosub and
resumes execution at that point.  (The stack used for this storage
is not accessable to the user.  This is a feature.)

=item shower

shows the current program segment and the current
program pointer.  It includes labels and command numbers.
Note that memory set aside by alloc is in the program segment
and so is displayed by this command.  This is useful for debugging.

=item store

stores the value of its first operand in its second operand.

=item subt

subtracts its first operand from its second operand
and stores the result in its second operand.

=item take

takes input from the user (via standard input) and stores it in
its only operand which is subject to addressing modes.  Do NOT put the
source file on standard input to B<assembly> if your source file contains the
take command or there will be a conflict between reading your code and
taking your user input.

=back

=head1 ADDRESSING MODES in PAL

Operands of jump, gosub and brxx functions which specify new
values for the program pointer are only looked up in the symbol table.
The operand to alloc must be a positive integer.
All other operands are subject to the following addressing modes:

  name of mode   example    description
  
  literal        12         any literal number
           Literal numbers must start with a digit.  For example,
           use 0.5 for one half instead of .5 which will confuse the parser.
  direct         myvar      use value of myvar
  indirect       @myvar     use myvar as a pointer
  auto post inc  @myvar+    indirect with post increment
  auto pre inc   @+myvar    indirect with pre increment
  auto post dec  @myvar-    indirect with post decrement
  auto pre dec   @-myvar    indirect with pre decrement
  address of     &myvar     returns address of myvar

When (if) implemented, the double indirect modes will be as above with
an additional @ sign:  @@myvar, @@+myvar, etc.
To restate, these are NOT available at this time.


=head1 EXAMPLES

The examples below were directly imported to this document from
executable files which were running.  They should work for you too.

The following is a somewhat convoluted program which prints the numbers
0 through 4 each on a line by itself, stores those same numbers in the
ar array and shows the state of the program space immediately before
exiting.

 ummy: alloc 1
    i: alloc 1
   ar: alloc 5

       store &ar ummy
       store 0 i
 loop: brge  i 5 fine
       gosub rout
       add   1   i
       jump  loop

 fine: shower
       end 0

 rout: prt i
       store i @ummy+
       ret

The following prompts for interest rate and mortgage amount, then
computes and prints the monthly payment for those inputs assuming
a thirty year mortgage with monthly payments and compounding.

     n:   alloc 1
     T:   alloc 1
 npays:   alloc 1
     r:   alloc 1
     M:   alloc 1
     R:   alloc 1
    Rn:   alloc 1
 onemRn:  alloc 1
 onemR:   alloc 1
 payment: alloc 1
    i:    alloc 1

        prompt "Enter annual nominal interest rate -> "
        take   r
        prompt "Enter initial mortgage balance -> "
        take   M
        store  12 n
        store  30 T
        store  n  npays
        mult   T  npays
 
        store  r  R
        div    n  R
        add    1  R
 
        store  1  i
        store  1  Rn
 loop:  brgt   i  npays   bot
        mult   R  Rn
        add    1  i
        jump   loop

 bot:   store  1  onemRn
        subt   Rn onemRn

        store  1  onemR
        subt   R  onemR

        store  onemR  payment
        div    onemRn payment
        mult   Rn     payment
        mult   M      payment

        prompt "Your monthly payment will be "
        prt    payment
        end    0

The following uses the new pushop and popop (introduced in version 0.20)
to manually manage recursive calls to calculate factorial.

  answer: alloc 1
  input:  alloc 1

  main:   prompt "Enter a small integer "
          take   input
          pushop input
          gosub  fact
          popop  answer
          prompt "The factorial of your number is "
          prt    answer
          end    0

  fact:   popop	 n
          brgt   n      1      domore
          pushop 1
          ret

  domore: pushop n
          subt   1      n
          pushop n
          gosub  fact
          popop  retval
          popop  n
          mult   n      retval
          pushop retval
          ret

  n:      alloc  1
  retval: alloc  1

=head1 OMISSIONS

=over 5

=item
Double indirect and base/offset addressing modes could be included.

=item
There are no registers.  One could simulate these by using alloc r1 1
etc.

=item
There is no direct access to the program pointer (this is a feature).

=item
All allocated memory is global.  There is no way to stack subroutine arguments.

=item
There are no flags to indicate underflow, overflow etc.

=item
The following command is not implemented:

  negate - use mult -1 var

=back

=head1 AUTHOR

Phil Crow  philcrow2000@yahoo.com

=head1 BUGS

You can't put colons in literal strings for the prompt command.  Allowing
these makes it harder to catch errors in labels.

I've fixed the other ones I've seen.  When you see the others, let me know.

=head1 PLEADING

I hope that you enjoy PAL, but you couldn't possibly enjoy it as much
as I do.  I hope that you share your joy with others, especially if
those others are students.  The driving force behind PAL is my desire
to expose future professional programmers to the workings of assembly.
Since many of them are bypassing a full course in assembly, I'm hoping
to talk you into wedging a two week unit on PAL into your Intro to
Computer Science sequence.

=head1 DEFENSIVENESS

Pal is small.  It doesn't have bells and whistles.  It won't, unless
you make your own version.  There are several reasons.

=over 4

=item 1.
 I wrote it in my spare time one week on the midnight shift.  I needed
something to do, not something to drive me nuts.

=item 2.
I wrote it partly to use in an Introduction to Computer Science course
sequence.  Too few students are being exposed to assembly these days.
The reasons are that assembly has become highly complex and little used.
I figure that a foundational language like this should not be left out.
Maybe it won't be, if I can at least remove the first reason for skipping it.

=item 3.
I wrote it to be a simple assembler into which I could compile other
toy languages.  Why should I support a myriad of commands I don't want
to use in my compiled code?

=item 4.
I wrote it as a tool to teach Perl.  Once students have played with
PAL source code for a while, they can easily move on to understanding
the assembly program itself.  They can add a better stack and cooler
addressing modes, etc.  This will improve their Perl skill.  Who
knows, writing the code might even drive home the point of how these
things really work.

=item 5.
I wrote it.

=back

=head1 PREREQUISITES

This script requires the C<strict> pragma and the C<Getopt::Std> module.

=head1 OSNAMES

linux
HP-UX
MSWin32

=head1 SCRIPT CATEGORIES

Educational/ComputerScience

=head1 EDIT HISTORY

 0.0   Spring    2000  Created
 0.1   Feb.      2002  Prepared for CPAN
 0.11  Feb. 22   2002  Fixed SCRIPT CATEGORIES
 0.12  Apr. 10   2002  Corrected label regex so labels can't be defined with
                       spaces in the name (which broke when you tried to use
		       them).
		       Fixed documentation errors.  The names of the arithmetic
		       operations were not abbreviated as they must be.
		       The examples were correct.
 0.13  Apr. 10   2002  Corrected label regex again, previous fix was still
                       wrong.
 0.14  Apr. 10   2002  Improved error messages during assembly.  Now they
                       print the offending line in addtion to its number.
 0.15  Apr. 16   2002  Improved error messages during run time.  Now they show
                       the text of the line which caused the error.  In many
		       cases, they now show the offending identifier in the
		       message text.
 0.20  Jun. 11   2002  Added pushop, popop, and the stack they use.  Now you
                       can implement true subroutines, but you must manually
		       manage the parameter stack.  Only the program pointer
		       stack is managed for you.
		       Added an example of pushop and popop to the POD section.
		       Removed incr and decr commands, use add and subt instead.
		       This keeps the command count at 21 statements and 1
		       directive.
 0.21  Jun. 12   2002  Corrected POD documentation so pod2html makes prettier
                       output.

=head1 COPYRIGHT

Copyright 2000-2002, Phil Crow

This program is free software and can be redistributed under the same terms
as Perl.

=cut
