#!/bin/bash
find app -type f -perm -o+w -exec chmod o-w {} +
