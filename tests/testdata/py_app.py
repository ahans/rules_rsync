"""Prints a data file found through the runfiles library."""

import sys

from python.runfiles import runfiles

r = runfiles.Create()
with open(r.Rlocation("_main/tests/testdata/greeting.txt")) as f:
    print("py:", f.read().strip(), *sys.argv[1:])
