#!/bin/sh
# 100-dev-rust.sh - included by .profile

#
# software development settings
#

if source_once dev_rust
then
    # Rust
    CARGO_HOME=${HOME}/.local/lib/cargo
    RUSTUP_HOME=${HOME}/.local/lib/rustup
    export CARGO_HOME RUSTUP_HOME
fi
