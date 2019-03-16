#!/bin/bash

silent () {
    # This function captures all the output (stdout and stderr) of the command
    # (and its arguments) passed by argument and will only output it if the
    # command doesn't return 0.

    tmp=$(mktemp) || return # this will be the temp file w/ the output
    set +e
    "$@" > "$tmp" 2>&1 # this should run the command, respecting all arguments
    ret=$?
    set -e
    if [ "$ret" -ne 0 ] ; then
        echo "$@"
        cat "$tmp"  # if $? (the return of the last run command) is not zero, cat the temp file
    fi
    rm -f "$tmp"
    return "$ret" # return the exit status of the command
}
