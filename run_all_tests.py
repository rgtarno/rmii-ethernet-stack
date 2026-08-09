#!/usr/bin/env python3

from vunit import VUnit
from glob import glob
import importlib
import sys


def create_test_suites(project):

    run_scripts = glob("**/run.py", recursive=True)
    run_scripts = [x for x in run_scripts if "vunit_deps" not in x]
    run_scripts = [x.replace('/', '.').strip(".py") for x in run_scripts]
    for script in run_scripts:
        print(f"Import from {script}")
        mod = importlib.import_module(script)
        mod.create_test_suite(project)


vu = VUnit.from_argv()
create_test_suites(vu)
vu.main()
