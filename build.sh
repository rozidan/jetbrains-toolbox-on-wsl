#!/usr/bin/env bash

printf "build image... "
docker build -t jetbrains-toolbox-wsl .
if [ "$?" != "0" ]; then
  printf "failed to build docker image\n"
  exit 1
fi
printf "done\n"

printf "run container... "
docker run --name jetbrains-toolbox-wsl jetbrains-toolbox-wsl
printf "done\n"

printf "export container... "
docker export -o jetbrains-toolbox-wsl.tar jetbrains-toolbox-wsl
docker container rm jetbrains-toolbox-wsl >/dev/null
printf "done\n"
