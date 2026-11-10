#!/bin/bash
cat > facts.env <<T
KERNEL_NAME=$(uname -s)
KERNEL_RELEASE=$(uname -r)
ARCH=$(uname -m)
T
cat facts.env
