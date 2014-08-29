libBIL
======

An intermediate language for binary derived from BAP (Binary Analysis Platform)

[BAP](http://bap.ece.cmu.edu/) is an amazing platform for binary analysis. BIL
is an intermediate language used in BAP. This library is to provide a standalone
version of BIL, thus it only includes the essential part of the language in BAP.

This project is forked off from [BAP](http://bap.ece.cmu.edu/) 0.7.

Dependency
----------

In Debian,

    apt-get install ocaml camlidl ocaml-findlib binutils-dev \
      libzarith-ocaml-dev libbatteries-ocaml-dev

