#!/bin/bash
# Reference solution
head -n 5 app.log > first5.txt
tail -n 5 app.log > last5.txt
cat first5.txt last5.txt
