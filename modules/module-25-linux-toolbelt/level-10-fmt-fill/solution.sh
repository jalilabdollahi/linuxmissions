#!/bin/bash
# fmt joins the lines of each paragraph and refills them; a blank line or a
# change of indentation starts a new paragraph, and the indentation is kept.
fmt -w 72 NOTES.txt > NOTES.wrapped
head -12 NOTES.wrapped
