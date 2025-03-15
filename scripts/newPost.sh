#!/usr/bin/env bash

if [ $# -eq 0 ]
  then
    echo "I can't proceed, I don't have an argument for the post location"
fi

post_name=$(gum input --placeholder "What would you like your post title to be?")

lower_post_name=$(echo "$post_name" | tr "[:upper:]" "[:lower:]")

stripped_post_name=$(echo "${lower_post_name}"| sed -e "s/ /-/g")
post_dir="$1"/"$stripped_post_name"

mkdir -p "$post_dir"

hugo new content "$post_dir"/index.md

gsed -i "/yourtitle/c\title: $post_name" "$post_dir"/index.md


hx "$post_dir"/index.md
