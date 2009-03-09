#!/bin/bash

LENGTH="20"
HALF="$(($LENGTH/2))"

if [ ${#PWD} -gt $(($LENGTH)) ]; then
   echo "${PWD:0:$(($HALF-3))}...${PWD:$((${#PWD}-$HALF)):$HALF}" | \
   sed 's/^$HOME/~/'
else
   echo "$PWD" | sed 's/^$HOME/~/'
fi
