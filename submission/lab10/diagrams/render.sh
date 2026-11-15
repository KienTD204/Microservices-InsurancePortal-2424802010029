#!/usr/bin/env bash
# Render every .puml in this folder to SVG and PNG with PlantUML (smetana layout, no Graphviz needed).
# Uses the Java runtime of an existing local Docker image; override PLANTUML_JAR / JAVA_IMAGE if needed.
set -euo pipefail
cd "$(dirname "$0")"
JAR_DIR="${PLANTUML_JAR_DIR:-$HOME/.vscode/extensions/jebbs.plantuml-2.18.1}"
IMAGE="${JAVA_IMAGE:-lab-eureka-server}"
if pwd -W >/dev/null 2>&1; then WORK="$(pwd -W)"; JAR_DIR="$(cd "$JAR_DIR" && pwd -W)"; else WORK="$(pwd)"; fi
for fmt in svg png; do
  MSYS_NO_PATHCONV=1 docker run --rm -v "$JAR_DIR:/p:ro" -v "$WORK:/w" --entrypoint java "$IMAGE" \
    -Djava.awt.headless=true -DPLANTUML_LIMIT_SIZE=16384 -jar /p/plantuml.jar -charset UTF-8 -t$fmt -o /w/out "/w/*.puml"
done
