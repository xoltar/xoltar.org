---
title: Mac OS X C++ Development (part 2)
---

![](/images/charlie-chaplin.jpg "C++ on Mac can make you sad"){ style="float:right;padding-left:1em;"}

As I wrote in my [previous post](/posts/2016-04-21-mac-os-x-native/), I recently
started working on a Mac. This is a collection of my notes on the problems and
surprises I ran into. Maybe it will be useful for you, too.

<!--more-->

Tools
=====

In addition to many of the command line tools you may be familiar with from C++
development on Linux, Mac OS X has specialized tools for working with binaries.

otool
-----
The `otool` utility displays information from binary headers. It works with Mach
headers (which are the main thing, on Macs) but also works with other "universal"
formats as well. There are many options, but the main one that's been helpful to
me so far has been `otool -L <lib>`, which tells you the dependencies of the
archive, which are essential debugging information for dynamic linking problems.
Another useful one is `otool -D <lib>`, which tells you the *install names*
embedded in a given library.

install_name_tool
-----------------

This tool allows you to change the *install names* for a binary. Simple, but important.

By now you must be wondering what *install names* are. 

Install Names
=============

Let us begin with `man dyld`. There is no `dyld` command. Nevertheless, it is
the dynamic linker for Mac OS X. The man page tells us many interesting things,
perhaps chief among which is how dynamic libraries are located at run-time.

When you link an application to a dynamic library, the path to that library is
encoded in the application binary. Well, actually, when you build, the library
is interrogated to find out where it is *supposed* to be installed, and *that*
path gets encoded in the application binary. These paths where things are
supposed to be installed are known as _install names_ on Mac OS X. Every .dylib
has (at least) one. You can use `otool -D` to find the install name of a .dylib
file.

In most cases, the install name will have an absolute path, like this:

```
> $ otool -D /usr/lib/libiconv.dylib
/usr/lib/libiconv.dylib:
/usr/lib/libiconv.2.dylib
``` 

So if you link with /usr/lib/libiconv.dylib, your application will look for
/usr/lib/libiconv.2.dylib when it launches. If the .dylib isn't where it's
expected, the app crashes.

Relative paths
--------------
Sometimes a library will have a relative path as its install name. When this
happens, dyld will search for a library with that name on several search paths.
It's similar to `LD_LIBRARY_PATH` in some ways. There are environment variables
you can set to control where it searches. There are several, and you should
consult `man dyld` if you want the gory details. One thing that is important to
know is that one of these variables, `DYLD_FALLBACK_LIBRARY_PATH`, has the
default value `$(HOME)/lib:/usr/local/lib:/lib:/usr/lib`. Occasionally you may
see advice on the web that recommends symbolic linking a library into your
`$(HOME)/lib` without any further explanation. `DYLD_FALLBACK_LIBRARY_PATH` is
why.

@rpath
-------
If you want to distribute an application that relies on libraries that are not
necessarily in known standard places, it is a good idea to use `@rpath` as part of
your install name. This directs dyld to look in a path that is relative to the
application binary (or in the case of a library that is dynamically linked to
another library, the path is relative to the calling library), rather than
looking in the places it normally would. This would allow you to bundle a set of
libraries along with your application, and have them be found regardless of
where you install the application. There are several other options, such as
`@executable_path` and `@loader_path`, but `@rpath` seems to be the right choice
in most cases. Again, `man dyld` has all the details. 

An Example: Dionysus
====================

I wanted to build [Dionysus](http://www.mrzv.org/software/dionysus/), a library
for working with
[persistent homology](https://en.wikipedia.org/wiki/Persistent_homology). I
wanted to build the Python bindings.

Linker Errors
-------------

After I managed to get through the compile phase, I ran into linker problems,
with unresolved symbol errors similar to the ones I mentioned in
[part 1](/posts/2016-04-21-mac-os-x-native). However, in this case, changing the
compiler didn't fix the problem. I was getting linking errors trying to link
with [Boost](http://www.boost.org/), which I had already reinstalled on my
system from source, using gcc:

```
export HOMEBREW_CC=gcc-5
export HOMEBREW_CXX=g++-5
brew reinstall --build-from-source boost
brew reinstall --build-from-source boost --with-python3
```

That wasn't enough though. I still got linker errors. Googling suggested maybe
the problem was that Boost.Python (which Dionysus uses for its Python binding)
was linked to a different version of Python than the one I was targeting. This
turned out to be a red herring, however. As far as I can tell, Boost.Python
doesn't actually link to Python at all (though it has to be compiled with
support for Python 3 if you want that, so there's certainly a connection, just
not a linking one). 

The problem actually was that Dionysus wanted the C++ 11 version of Boost, and
the default Homebrew version doesn't have that support. For this, you need:

```
brew reinstall --build-from-source boost --with-c++11
brew reinstall --build-from-source boost-python --with-c++11
```

Build-time linking errors resolved, I thought I was home free.

Dynamic Linking Errors
----------------------

At last, I had built the library. I fired up python2.7, imported the library. It
worked! Then I created an instance of one of the classes, and got this: 

```
TypeError: __init__() should return None, not 'NoneType'
```

After a lot of googling, it turned out that the most likely cause for this was
that the Dionysus binding had wound up linked to the wrong Python library. I
carefully checked the CMakeCache.txt file and eliminated any occurrences of the
wrong Python library, or the wrong Boost library. Still no luck.

A look at ```otool -L``` output for the library showed something funny:

```
> $ otool -L lib_dionysus.dylib                                                
lib_dionysus.dylib:
	/Users/me/src/Dionysus/build/bindings/python/lib_dionysus.dylib (compatibility version 0.0.0, current version 0.0.0)
	libpython2.7.dylib (compatibility version 2.7.0, current version 2.7.0)
	/usr/local/opt/boost-python/lib/libboost_python-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
	/usr/local/opt/mpfr/lib/libmpfr.4.dylib (compatibility version 6.0.0, current version 6.3.0)
	/usr/local/opt/gmp/lib/libgmp.10.dylib (compatibility version 14.0.0, current version 14.0.0)
```

Do you notice that all the entries are absolute paths except for the
libpython2.7 one? A quick look at the Anaconda libpython2.7.dylib I linked
against shows why:

```
> $ otool -D /Users/me/anaconda2/lib/libpython2.7.dylib
/Users/me/anaconda2/lib/libpython2.7.dylib:
libpython2.7.dylib

```

So Anaconda's version of Python instructed the linker to find libpython2.7.dylib
by going through the normal dyld process - checking DYLD_LIBRARY_PATH, then
DYLD_FALLBACK_LIBRARY_PATH, and so on. Since /usr/lib is on
DYLD_FALLBACK_LIBRARY_PATH by default, and the system libpython2.7.dylib is in
that directory, Dionysus was getting linked with that one, *not* with the one
that was already in memory in the current process. This led to the strange error
I saw.

I was able to use `install_name_tool` to change the binary to
point to the *right* libpython2.7:

```
> $ install_name_tool lib_dionysus.dylib -change libpython2.7.dylib /Users/me/anaconda2/lib/libpython2.7.dylib
```

After this, everything was fine.

Further reading
===============

In addition to `man dyld`, these are useful:

- [Linking and Install Names](https://www.mikeash.com/pyblog/friday-qa-2009-11-06-linking-and-install-names.html)
- [Runpath Dependent Libraries](https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/DynamicLibraries/100-Articles/RunpathDependentLibraries.html)
- [Using C++11 in Mac OS X with compiled Boost libraries](http://stackoverflow.com/questions/18139710/using-c11-in-macos-x-and-compiled-boost-libraries-conundrum)
- [Boost Python init should return None not NoneType](http://stackoverflow.com/questions/20437769/boost-python-init-should-return-none-not-nonetype)
- [Relative paths in otool output](http://stackoverflow.com/questions/26439319/relative-paths-in-otool-output)
