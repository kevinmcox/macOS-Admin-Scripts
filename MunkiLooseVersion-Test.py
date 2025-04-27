#!/usr/local/munki/munki-python

# Test how Munki will evaluate versions and decide which is the highest (newest)
# Original written by Greg Neagle and shared in the MacAdmins Slack
# Added to this repo so I can easily find it when needed

import sys

sys.path.insert(0, "/usr/local/munki")
from munkilib.pkgutils import MunkiLooseVersion

# Enter version numbers to test in the list below:

version_numbers = [
    "1",
    "2",
    "3",
    "AI-243.24978.46.2431.13363775",
    "AI-243.22562.218.2431.13114758",
    "AI-242.21829.142.2421.12409432",
]

print(*sorted(version_numbers, key=MunkiLooseVersion, reverse=True), sep="\n")
