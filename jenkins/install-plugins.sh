#!/usr/bin/env bash
set -e

PLUGINS_FILE="$1"

echo "Instalando plugins START"

jenkins-plugin-cli --plugin-file $PLUGINS_FILE

echo "Instalando plugins END"