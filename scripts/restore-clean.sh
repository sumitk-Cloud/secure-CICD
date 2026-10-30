#!/usr/bin/env bash
# Restore the clean dependency list after the failure demo.
set -e
cp tests/requirements.backup app/requirements.txt
echo "Clean requirements restored. Commit and push to see the pipeline pass."
