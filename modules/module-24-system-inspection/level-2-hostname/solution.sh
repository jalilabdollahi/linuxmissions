#!/bin/bash
sed -i "s/^hostname = .*/hostname = $(hostname)/" agent.conf
grep -n 'hostname' agent.conf
