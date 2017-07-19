#!/bin/sh

# this script parses out the headings and commands from the REAMDE.md and executes them
CMD=`cat README.md | sed 's/^#\+\s/    echo "step: /g' | awk '/echo \"step: /{$0=$0"\""}{print}' | grep "^\s\s\s\s.*"`

bash -ce "$CMD"
