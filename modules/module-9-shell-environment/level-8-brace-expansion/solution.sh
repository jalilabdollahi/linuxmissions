#!/bin/bash
mkdir -p data/2026/{01..12} svc/{api,web,worker}/{dev,prod}/{conf,logs}
cp config.yaml{,.bak}
find data svc -type d | sort | head
