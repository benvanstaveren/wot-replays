#!/usr/bin/python
import pickle;

print(pickle.dumps({ "Scrambled": "Leave the MS-1 alone :P" }, 2))
print(pickle.dumps("Leave the MS-1 alone :P", 2))
