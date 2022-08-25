#!/bin/sh
# run-clean.sh - clean up build files in shuffle subdirectories
# by Ian Kluft
# See https://github.com/ikluft/ikluft-tools/tree/master/shuffle
#
# Open Source licensing under terms of GNU General Public License version 3
# SPDX identifier: GPL-3.0-only
# https://opensource.org/licenses/GPL-3.0
# https://www.gnu.org/licenses/gpl-3.0.en.html

(cd cpp; make clean)
(cd go; go clean shuffle.go)
(cd rust; cargo clean)
