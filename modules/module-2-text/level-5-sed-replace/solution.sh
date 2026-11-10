#!/bin/bash
# Reference solution: escape the dot, replace every occurrence per line, keep the original.
sed 's/staging\.internal/prod.internal/g' config.conf > config.prod.conf
diff config.conf config.prod.conf
