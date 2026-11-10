#!/bin/bash
# Excludes first, then the directory. Each pattern matches whole names at any depth.
tar -czf release.tar.gz --exclude-vcs --exclude=node_modules --exclude='*.log' --exclude=.env app
tar -tzf release.tar.gz | sort
