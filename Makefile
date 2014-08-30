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
	$(OCAMLBUILD) -Is src,libbfd -Xs buildtools bil.cmxa toil.native

clean: depcheck
	$(OCAMLBUILD) -clean
	rm -f libbfd/bfdarch.idl

depcheck: Makefile.dep
	@buildtools/depcheck.sh $<

libbfd/libbfd.idl: libbfd/bfdarch.idl

libbfd/bfdarch.idl:
	echo '#include "bfd.h"' \
		| $(CC) -E -xc - \
		| awk 'BEGIN { go=0; } /^enum bfd_architecture$$/ { go=1; } \
		       go && $$0 != "" { print; } \
		       /machine_t/ { print; } \
		       /};$$/ { go=0; }' \
		| sed 's,bfd_arch_,arch_,' \
		| sed 's,enum bfd_architecture,enum architecture,' \
		  > libbfd/bfdarch.idl

.PHONY: all clean depcheck
