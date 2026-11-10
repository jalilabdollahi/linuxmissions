#!/bin/bash
find webroot -type d -exec chmod 755 {} +
find webroot -type f -exec chmod 644 {} +
