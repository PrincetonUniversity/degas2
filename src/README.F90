Fortran 90 changes:

(A) Memory allocation.  Degas 2 can use Fortran 90 semantics for dynamic
memory allocation.

Use var_alloc, var_realloc, var_free for memory allocation.

Don't use int_alloc, real_alloc, etc.  Include

    @<Memory allocation interface@>

in declaration section of calling routine (this is currently the only
user of the new "interface" feature of Fortran 90 in DEGAS 2)

Instead of
	subroutine foo
	ptr_decl(x)
	real x(n)

	real_alloc(x,n)
	...
	real_free(x,n)

use
	subroutine foo
	define_dimen(ind,n)
	define_varp(x,FLOAT,ind)
	implicit_none_f77
	...
	declare_varp(x)
	@<Memory allocation interface@>

	var_alloc(x)
	...
	var_free(x)


(B) Include files.

Treat these as a whole number of WEB modules.  So

    @I foo.hweb
    @f foo_decl integer

won't work.  Instead do

    @f foo_decl integer
    @I foo.hweb

or

    @I foo.hweb
    @ New module.
    @f foo_decl integer


Degas2 packages:

Include
	 package_end(pk)
at the end of package.

define_dummy_pk is no longer needed.  There are separate common blocks for
each data type, so no padding is required.

define_varlocal_pk is new and used to define the _version strings.  It is
tentatively defined to declare a variable which is not written/read to
netcdf files (with ncwrite/ncread).

The package mechanism defines pk_common.  (There's no pk_common_a,
pk_common_b, now.)  Don't define additional macro names as *_common, since
"make depend" searchs for this pattern.  Instead use *_decls,
*_localcommon, or whatever.

(C) F90 Modules.

Under f77, degas 2 included pointers in common blocks.  This is nonstandard
in f90 (and nonstandard in f77 for that matter).  The f90 equivalent is
modules which provide a generalization of common blocks.

There are two issues:

(1) the module definitions are separate compilation units, and different
f90 implementations seem to have different ways of locating the
definitions.

(2) a subroutine which uses a module needs to include "use module" BEFORE
anything else (including the "implicit none").

ftangle is set up to have pk_common produce either a common block (f77) or
a use statement (f90).  The correct placement is acheived by bracketing
these with
      implicit_none_f77
      ...
      implicit_none_f90

e.g.,

      subroutine xxx
      implicit_none_f77
      dm_common
      rd_common
      implicit_none_f90


(D) Details about how module definitions are found.  There are (at least)
three methods by which module information is shared.

Suppose that a module "mmm" is defined in 
    header.f
(and that this contains no executable code) and that
    routine.f
includes
    use mmm

Solaris.
    f90 -c header.f -> header.o header.M
    f90 -M. -c routine.f -> routine.o   # scans cwd for definition of mmm in all .M files.
    f90 -o prog routine.o        # header.o not used (but may be included?)

OSF/1 & Linux
    f90 -c header.f -> header.o mmm.mod
    f90 -I. -c routine.f -> routine.o   # scans the current directory for mmm.dm
    f90 -o prog routine.o header.o

C90
    f90 -c header.f -> header.o
    f90 -p. -c routine.f -> routine.o # scans . for defn of mmm in all .o files
    f90 -o prog routine.o header.o

(E) make depend
produces the dependencies to make this happen.

mmm_MOD:=header_mod.$O
routine_mods:= $(mmm_MOD) ...

In addition, the Makefile includes rules:

%.mweb: %.hweb makemodule
	./makemodule $< $@

%_mod.f: %.mweb
	$(FTANGLE) -I$(SOURCEDIR) ... -m$(TARGET) -=n=#_mod.f $<

So a header file gets processes as
    header.hweb -> header.mweb -> header_mod.f -> header_mod.o

Each program needs to have a Makefile definition as in

datasetup: $(datasetup) $(foreach arg,$(subst .$O,_mods,$(datasetup)),$($(arg)))

to get the module definitions linked in.  (STILL TO DO.)

The listing of object files now needs to include the "main" object file
also (to make the _mods business work).

Thus
    randomtest = random.$O randother.$O
becomes
    randomtest = randomtest.$O random.$O randother.$O

(F) Other Makefile issues.

f90 processes is selected with FORTRAN90=yes.  You should probably do a
"make clean" when switching from f77 to f90.

Makefile.local is included if it's available.  E.g.,

    echo "FORTRAN90=yes" > Makefile.local

causes f90 to be used.

(G) Precision.  Degas 2 (in Fortran90 mode) now uses the REAL(KIND=..)
specification of precision.  For this to work conveniently, the following
coding practises need to be used:

(a) ALL functions and subroutines need to contain

      implicit_none_f77
      ... optional package commons ...
      implicit_none_f90

(b) Declare the type of function in a separate statement, e.g., instead of

      real function f(x)

use

      function f(x)
      implicit_none_f77
      ...
      implicit_none_f90
      real f

ftangle converts this to

      function f(x)
      implicit none
      integer,parameter::SINGLE=kind(0.0),DOUBLE=selected_real_kind(12)
      REAL(kind=DOUBLE) f


(H) Other...

f90 is flakely on Suns and NERSC computers.  I'm almost certain this is due
to compiler bugs and not my interpretation of f90.  So check out all the
f90 stuff on hydra for now.

set_inc in xsection.hweb was behaving unpredicably.  (Sometimes, one of the
do loop indices is missing from the body.)  Can this be replaced by a
fortran do loop (see alternate definition in xsection.hweb).

All the memory allocation in degas2 is now standard f90.
