#!/bin/bash

###############################################################################
# OCaml dependency checker                                                    #
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

bincheck () {
  type "$1" > /dev/null 2> /dev/null
  if (( $? > 0 )); then
    echo "Error: $1 does not exist."
    echo "       Please see the installation instruction for more information."
    exit 1
  else
    return 0
  fi
}

libcheck () {
  libname=$1
  libversion=$2

  if [ -z $libversion ]; then
    libversion=0.0
  fi

  libstring=$(ocamlfind list |
    sed 's,\[internal\],,' | sed 's,\[distributed with Ocaml\],,' | tr -d ')' |
    awk '{if (length($3) == 0) {print $1",0.0"} else {print $1","$3}}' |
    grep "^$libname," 2> /dev/null)

  if (( $? > 0 )); then
    echo "Error: ocaml library [$1] does not exist."
    echo "       Please see the installation instruction for more information."
    exit 1
  fi

  echo $libstring |
  awk -F',' '{dif= $2 - '$libversion'; if (dif >= 0) {exit 0} else {exit 1}}' \
    2> /dev/null

  if (( $? > 0 )); then
    echo "Error: the version of ocaml library [$1] must be >= $libversion"
    echo "       Please see the installation instruction for more information."
    exit 1
  fi

  return 0
}

### self sanitization
bincheck "awk"
bincheck "sed"
bincheck "tr"
bincheck "ocamlfind"

### reading input
depfile=$1

if [ -z $depfile ];then
  echo "Error: Must provide a dependency file to $0"
  echo ""
  cat << EOF
Usage: $0 <dependency file>

    Dependency files must include a dependency command per line. A
    dependency command is a comma-separated tuple, which checks either
    a binary dependency or a library dependency.

    A binary dependency can be specified using a 2-tuple: (bin, binary
    name). The first field specifies a command, thus it should not be
    changed.

    A library dependency can be specified either by:
        2-tuple (lib, library name)
    or
        3-tuple (lib, library name, required version).

    The following example dependency file checks two dependencies:
    (1) check if the binary "ocaml" presents in the system;
    (2) check if the library (batteries) exists in the system and if
    the library has a version greater or equal to 2.1.

    (An example dependency file)
    bin,ocaml
    lib,batteries,2.1

EOF
  exit 1
fi

### parsing the dependency file
for line in $(cat $depfile | grep -v '^#' | grep -v '^\s+$'); do
  IFS=, read cmd name ver <<<$line
  if [[ $cmd == "bin" ]]; then
    bincheck $name
  elif [[ $cmd == "lib" ]]; then
    libcheck $name $ver
  fi
done
