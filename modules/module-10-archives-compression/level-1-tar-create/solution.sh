#!/bin/bash
# Change into build/dist for the packing, so members start with site/.
tar -czf release-2.3.tar.gz -C build/dist site
tar -tzf release-2.3.tar.gz
