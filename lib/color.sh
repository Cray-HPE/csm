#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

# Is stdout a TTY?
[[ -t 1 ]] || return

# Color supported?
ncolors=$(tput colors)
[[ -n "$ncolors" && $ncolors -ge 8 ]] || return

nc="$(tput sgr0)"
bold="$(tput bold)"
underline="$(tput smul)"
standout="$(tput smso)"
black="$(tput setaf 0)"
red="$(tput setaf 1)"
green="$(tput setaf 2)"
yellow="$(tput setaf 3)"
blue="$(tput setaf 4)"
magenta="$(tput setaf 5)"
cyan="$(tput setaf 6)"
white="$(tput setaf 7)"
