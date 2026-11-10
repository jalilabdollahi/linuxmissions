#!/bin/bash
# Name exactly 2..12; brace expansion avoids the app.log* and app.log.1* traps.
gzip -9 logs/app.log.{2..12}
gzip -l logs/*.gz
