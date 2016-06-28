---
title: Python Class Properties
---

![](/images/Threeclasses.jpg){ style="float:left;padding-right:1em;"}

Class properties are a feature that people coming to Python from other
object-oriented languages expect, and expect to be easy. Unfortunately, it's
not. In many cases, you don't actually want class properties in Python - after
all, you can have first class module-level functions as well, you might very
well be happier with one of those.

I sometimes see people claim that you can't do class properties at all in
Python, and that's not right either. It can be done, and it's not too bad. Read
on!

<!--more-->

I'm going to assume here that you already know what class (sometimes called
"static") properties are in languages like Java, and that you're somewhat
familiar with Python metaclasses. 

To make this feature work, we have to use a metaclass. In this example, we'll suppose
that we want to be able to access a list of all the instances of our class, as
well as reference to the most recently created instance. It's artificial, but it
gives us a reason to have both read-only and read-write properties. We
define a metaclass, which is again a class that extends `type`.

```python

class Extent(type):
    @property
    def extent(self):
        ext = getattr(self, '_extent', None)
        if ext is None:
            self._extent = []
            ext = self._extent
        return ext
        
    @property
    def last_instance(self):
        return getattr(self, '_last_instance', None)
        
    @last_instance.setter
    def last_instance(self, value):
        self._last_instance = value
        
``` 
Please *note* that if you want to do something like this for real, you may well
need to protect access to these shared class properties with synchronization
tools like
[RLock and friends](https://docs.python.org/3.5/library/threading.html#rlock-objects)
to prevent different threads from overwriting each others' work willy-nilly.

Next we create a class that uses that metaclass. The syntax is different in
Python 2.7, so you may need to adjust if you're working in an older version.

```python
class Thing(object, metaclass=Extent):
    def __init__(self):
        self.__class__.extent.append(self)
        self.__class__.last_instance = self
        
```
Another *note* for real code: these references (the `extent` and the
`last_instance`) _will_ keep your object from being garbage collected, so if you
actually want to keep extents for your classes, you should do so using something
like [weakref](https://docs.python.org/3/library/weakref.html).

Now we can try out our new class:

```python

>>> t1 = Thing()
>>> t2 = Thing()
>>> Thing.extent
[<__main__.Thing object at 0x101c5d080>, <__main__.Thing object at 0x101c5d2b0>]
>>> Thing.last_instance
<__main__.Thing object at 0x101c5d2b0>
>>> 
```

Great, we have what we wanted! There are a couple of things to remember, though:

- Class properties are inherited!
- Class properties are not accessible via instances, only via classes.

Let's see an example that demonstrates both. Suppose we add a new subclass of
`Thing` called `SuperThing`:

```python
>>> class SuperThing(Thing):
...     @property
...     def extent(self):
...             return self.__class__.extent
... 
>>> s = SuperThing()
```

See how we created a _normal_ `extent` property that just reads from the class
property? So we can now do this:

```python
>>> s.extent
[<__main__.Thing object at 0x101c5d080>, <__main__.Thing object at 0x101c5d2b0>, <__main__.SuperThing object at 0x101c5d2e8>]
```

Whereas if we were to try that with one of the original `Thing`s, it wouldn't
work:

```python
>>> t1.extent
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
AttributeError: 'Thing' object has no attribute 'extent'
```

We can of course still access either one via classes:

```python
>>> t1.__class__.extent
[<__main__.Thing object at 0x101c5d080>, <__main__.Thing object at 0x101c5d2b0>, <__main__.SuperThing object at 0x101c5d2e8>]
>>> s.__class__.extent
[<__main__.Thing object at 0x101c5d080>, <__main__.Thing object at 0x101c5d2b0>, <__main__.SuperThing object at 0x101c5d2e8>]
>>> 
```

Also note that the extent for each of these classes is the same, which shows
that class properties are inherited.

Did you spot the bug in `Thing`? It only manifests when we have subclasses like
`SuperThing`. We inherited the `__init__` from `Thing`,
which adds each new instance to the extent, and sets `last_instance`. In this
case, `self.__class__.extent` was already initialized, on `Thing`, and so
we added our `SuperThing` to the existing list. For `last_instance`, however, we
assigned directly, rather than first reading and appending, as we did with the
list property, and so `SuperThing.last_instance` will be our `s`, and
`Thing.last_instance` will be our `t2`. Tread carefully, it's easy to make a
mistake with this kind of thing! 

Hopefully this has been a (relatively) simple example of how to build your own class properties,
with or without setters.


