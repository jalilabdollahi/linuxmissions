#!/bin/bash
# Reference solution: -p creates missing parents and is fine with data/ existing.
mkdir -p logs/{app,nginx} data/uploads data/cache/thumbnails tmp/sessions
ls -R logs data tmp
