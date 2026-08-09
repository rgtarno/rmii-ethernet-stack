#! /bin/bash

set -eu

IMAGE_NAME=ghdl/ext:latest
CONTAINER_NAME=vhdl_dev

docker pull ${IMAGE_NAME}


docker run --rm -it -v "$(pwd)":"$(pwd)" --workdir "$(pwd)" --user "$(id -u)":"$(id -g)" \
	-v /tmp/.X11-unix:/tmp/.X11-unix --network host -e DISPLAY="${DISPLAY}" \
	-v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro -v /etc/shadow:/etc/shadow:ro \
	-v "${HOME}"/.bashrc:"${HOME}"/.bashrc:ro --hostname ghdl-vunit --name "${CONTAINER_NAME}" \
	${IMAGE_NAME} /bin/bash -l
