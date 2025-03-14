#!/usr/bin/env bash

if [ $# -eq 0 ]
  then
    echo "I can't proceed, I don't have an argument for the post location"
fi

post_name=$(gum input --placeholder "What name for your post?")
post_dir="$1"/"$post_name"

mkdir -p "$post_dir"

hugo new content "$post_dir"/index.md

hx "$post_dir"/index.md
