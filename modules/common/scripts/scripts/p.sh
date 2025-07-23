#!/usr/bin/env bash

claude -p "$*" --model sonnet --permission-mode plan --add-dir="$HOME" | glow --preserve-new-lines=false