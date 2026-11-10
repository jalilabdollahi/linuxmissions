#!/bin/bash
# Reference solution
mkdir extracted
tar -xzf backup.tar.gz -C extracted
tar -czf archive.tar.gz logs/*.log
tar -tzf archive.tar.gz
