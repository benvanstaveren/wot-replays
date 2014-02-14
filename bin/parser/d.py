#!/usr/bin/python
import pickletools
f = open('test.pickle', 'r')
print pickletools.dis(f.read())
