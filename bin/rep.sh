#!/bin/bash

OUT=0
while [ $OUT -eq 0 ]
do
    ./reparse-new.pl
    OUT=$?
done
