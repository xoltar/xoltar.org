---
title: Mac OS X C++ Development
---

![](/images/black-and-white-person-feeling-smiling.jpg "C++ on Mac can be crazy-making"){ style="float:right;padding-left:1em;"}

I recently switched to a MacBook Pro. I have customers that use Linux and Mac,
and I wanted to work in a similar environment. Also recently (a few months before
the MacBook) I started working with C++ again after a long hiatus.

I had thought that the Mac, being a Unix, would be relatively close to Linux,
and that things I was building for Linux would be much more likely to work there
than on Windows. That might still be true, but it turns out that there are
several things on Mac that are not obvious, and seriously complicate native code
development compared with Linux. These are my notes on those differences and how
to deal with them. Hopefully, it may be useful for other migrants to Mac as well.

<!--more-->

Xcode
=====

Apple includes something called Xcode. This is apparently a combination of a
platform SDK, and an IDE with a user interface similar to iTunes. You have to
have it, but you don't have to use the IDE part. It must be installed from the
App Store. Don't fight it, just install it and move on.

Command line tools
------------------

You definitely want the Xcode command line tools. Run:

```
xcode-select --install
```

to install them. This will give you git as well.

Brew
====

There are actually two package managers for Mac OS X,
[MacPorts](https://www.macports.org/) and [Homebrew](http://brew.sh/), and as a
developer you'll definitely need one of them. I use brew, because other people I
know recommended it, and it's been nice so far. You need it to install libraries
and tools that don't come with the Mac. Most notably gcc, cmake, and so on.


Clang and gcc
=============

Apple ships the [clang](http://clang.llvm.org/) compiler with Mac OS X, so this
is the considered the _standard_ compiler for the platform. This means that some
libraries (notably [Qt](http://clang.llvm.org/)) **only** support building with
clang.

Some C/C++ projects assume (incorrectly) that everybody builds with gcc. For this
reason (I guess), Apple did a really odd thing: they ship a gcc executable,
which is actually clang in disguise:

```
> $ gcc
clang: error: no input files
```

This (I guess) works sometimes, since many flags work the same in both
compilers. However, it is deeply confusing and causes problems as well. For
example, gcc supports [OpenMP](http://openmp.org/wp/), a powerful parallel
computing tool, and crucial for the work I'm doing. Recent versions of clang
support it as well, but Apple's fork of clang that ships with Macs **does not**.
So to use OpenMP, I have to have the real gcc. This will cause other problems
down the road, we'll get to them in a bit.

You'll want to install gcc with brew:

```
brew install gcc gdb
```

Since clang is already masquerading as gcc, the Homebrew folks came up with a workaround - the
gcc package installs executables called gcc-5 and g++-5 instead of
gcc and g++. I added the following in my profile to encourage build systems to
use these compilers instead of clang.

```
export HOMEBREW_CC=gcc-5
export HOMEBREW_CXX=g++-5
export CC=gcc-5
export CXX=g++-5

```

Note the Homebrew-specific ones. Homebrew generally installs binary, precompiled
packages rather than compiling on your machine, but you can pass
`--build-from-source` to it to make it recompile. If you do that, it will honor
the `HOMEBREW_CC` and `HOMEBREW_CXX` environment variables and use those to do
the build.

I also aliased cmake to ensure that cmake uses gcc-5 and g++-5 by default as
well:

```
alias cmake=/usr/local/bin/cmake -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX
```

Compatibility
-------------

C++, unlike C, doesn't specify a binary interface standard. This means that
libraries that are compiled with different C++ compilers can have problems
interoperating. So there's that to consider when you use things that were
compile with clang (such as anything you download using brew without
recompiling) together with things you've been building with g++-5. 

The most pressing example of this is related to the C++ standard library. There
are, on Mac (and elsewhere too I suppose), at least two implementations:
libstdc++, and libc++. By default, clang uses libc++ and gcc-5 uses libstdc++.
In practice, this means that if you install a C++ based library with brew, you
will be able to compile against it with g++-5, but when you get to the link
stage, it will fail with lots of missing symbols. If this happens,

```
brew reinstall --build-from-source <package>
```

can often fix the problem. However, there are brew packages (e.g. pkg-config)
that will fail to compile under g++-5, so there can be cases where this doesn't
work. One example: I was trying to build [mxnet](https://github.com/dmlc/mxnet)
directly using the brew package for [OpenCV](http://opencv.org/) support, and it
failed with the aforementioned link errors. I tried to reinstall opencv with
`--build-from-source` with brew, and it started recompiling all of opencv's (_many_)
dependencies, including pkg-config, which for some reason fails to compile. So
in the end I had to pull opencv as well and build it manually, after which mxnet
built fine too.

Next time
---------

These were some important things to be aware of when starting to develop in C++
on Macs. In the [next installment](/posts/2016-05-03-mac-os-x-native-2), we'll talk about dynamic libraries, install
names, and other such loveliness.
