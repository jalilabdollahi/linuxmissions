#!/bin/bash
# -i converts only the initial (leading) whitespace; -t 2 sets tab stops every 2 columns.
# Redirecting straight into deploy.yaml would empty it, so go through a temp file.
expand -i -t 2 deploy.yaml > deploy.yaml.new && mv deploy.yaml.new deploy.yaml
cat -A deploy.yaml | head -12
