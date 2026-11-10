#!/bin/bash
# Only directories: find -type d picks them (spaces and dot-directories included).
find projects -type d -exec chmod g+s {} +
find projects -type d -exec ls -ld {} +
