#!/bin/bash
# Key = field 2 only; -s keeps lines with equal keys in input order.
sort -s -k2,2 queue.txt > queue_sorted.txt
head queue_sorted.txt
