#!/bin/sh
printf '\033c\033]0;%s\a' Proyecto Limbo
base_path="$(dirname "$(realpath "$0")")"
"$base_path/limbo_server.x86_64" "$@"
