###############################################################################
# libBIL Makefile                                                             #
#                                                                             #
# Copyright (c) 2014, Sang Kil Cha                                            #
# All rights reserved.                                                        #
# This software is free software; you can redistribute it and/or              #
# modify it under the terms of the GNU Library General Public                 #
# License version 2, with the special exception on linking                    #
# described in file LICENSE.                                                  #
#                                                                             #
# This software is distributed in the hope that it will be useful,            #
# but WITHOUT ANY WARRANTY; without even the implied warranty of              #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                        #
###############################################################################

OCAMLBUILD=ocamlbuild

all: depcheck libbfd/libbfd.idl
	$(OCAMLBUILD) -Is src,libbfd -Xs buildtools bil.cmxa bil.cma toil.native

clean: depcheck
	$(OCAMLBUILD) -clean
	rm -f libbfd/bfdarch.idl

depcheck: Makefile.dep
	@buildtools/depcheck.sh $<

libbfd/libbfd.idl: libbfd/bfdarch.idl

libbfd/bfdarch.idl:
	echo '#include "bfd.h"' \
		| $(CC) -DPACKAGE -E -xc - \
		| awk 'BEGIN { go=0; } /^enum bfd_architecture$$/ { go=1; } \
		       go && $$0 != "" { print; } \
		       /machine_t/ { print; } \
		       /};$$/ { go=0; }' \
		| sed 's,bfd_arch_,arch_,' \
		| sed 's,enum bfd_architecture,enum architecture,' \
		  > libbfd/bfdarch.idl

install: depcheck all
	@ocamlfind remove libbil
	ocamlfind install libbil META \
		_build/src/bil.a \
		_build/src/bil.cmxa \
		_build/src/libBil.cmi \
		_build/src/libBil.mli \
		_build/src/arch.cmi \
		_build/src/arch.mli \
		_build/src/arithmetic.cmi \
		_build/src/ast.cmi \
		_build/src/dominator.cmi \
		_build/src/type.cmi \
		_build/src/type.mli \
		_build/src/var.cmi \
		_build/src/var.mli \
		_build/src/disasm_i386.cmi \
		_build/src/disasm_i386.mli \
		_build/src/pp.cmi \
		_build/src/cfg.cmi \
		_build/src/cfg.mli \
		_build/src/cfg_ast.cmi \
		_build/src/cfg_ast.mli \
		_build/src/big_int_convenience.cmi \
		_build/libbfdarch_stubs.a \
		_build/libbfdwrap_stubs.a

.PHONY: all clean depcheck install
