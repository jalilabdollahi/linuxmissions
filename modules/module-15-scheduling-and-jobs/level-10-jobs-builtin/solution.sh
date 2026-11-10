#!/bin/bash
./import.sh eu & eu=$!
./import.sh us & us=$!
./import.sh apac & apac=$!
jobs -l
wait "$eu"; echo "eu=$?" > statuses.txt
wait "$us"; echo "us=$?" >> statuses.txt
wait "$apac"; echo "apac=$?" >> statuses.txt
cat statuses.txt
