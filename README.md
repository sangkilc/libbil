libBIL
======

An intermediate language for binary derived from BAP (Binary Analysis Platform)

[BAP](http://bap.ece.cmu.edu/) is an amazing platform for binary analysis. BIL
is the intermediate language used in BAP. This library is to provide a
standalone version of BIL, thus it only includes the essential part of the
language in BAP.

This project is forked off from [BAP](http://bap.ece.cmu.edu/) 0.8.

Dependency
----------

* GNU Make
* Findlib
* Zarith (above 1.2)
* Batteries (above 2.1)
* BinUtils

Installation
------------

### Using default package managers

* Debian/Ubuntu

```
apt-get install ocaml camlidl ocaml-findlib binutils-dev \
  libzarith-ocaml-dev libbatteries-ocaml-dev
```

### Using Opam

In old Linux distribution, where the required libraries in its own package
management system have lower versions than required, we recommend you to use
opam.

```
opam install ocamlfind camlidl zarith batteries
```

When you use Opam, it is still necessary to install BinUtils. You can use the
following commands:

* Debian/Ubuntu

```
apt-get install binutils-dev
```

* Fedora/CentOS

```
yum install binutils-devel
```
