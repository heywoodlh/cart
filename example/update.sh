#!/bin/zsh

# Hardcode PATH to ensure MacOS-provided executables are exclusively used
PATH="/bin:/usr/bin:/sbin:/usr/sbin"

# Update cart.sh in same working directory
target_file="./cart.sh"

mkdir -p /tmp/cart/downloads
while read line
do
  # Skip lines not beginning with "cart"
  if echo -n "${line}" | grep -iqE '^cart'
  then
     # Parse ./cart.sh
     url="$(echo -n "${line}" | awk '{print $2}')"
     old_hash="$(echo -n "${line}" | awk '{print $3}')"
     filename="$(curl --silent --output-dir /tmp/cart/downloads -OJsL \"${url}\" -w \"%{filename_effective}\")"
     new_hash="$(shasum -a 256 ${filename} | awk '{print $1}')"
     echo "Url: ${url}"
     echo "Old hash: ${old_hash}"
     echo "New hash: ${new_hash}"
     echo "File: ${filename}"

     # Update URLs to current hashes
     sed "s|${url} ${old_hash}|${url} \"${new_hash}\"|g" "${target_file}"
     rm ${filename}
  fi
done <"${target_file}"
