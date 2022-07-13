#!/usr/bin/env python3
""" shuffle text lines from input file"""
# usage: shuffle.py infile > outfile
# by Ian Kluft
import sys
import random

# read list from file
file = sys.argv[1]
with open(file, 'r') as infile:
    words = infile.readlines()

# shuffle list and output
random.shuffle(words)
sys.stdout.writelines(words)
