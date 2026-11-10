#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
apt-cache madison fluxd libflux1
apt-get install -y --allow-downgrades fluxd=3.1.4-1 libflux1=1.4.2-1
