.ONESHELL:
SHELL = bash

.DEFAULT_GOAL := all

.PHONY: install-asdf-tools
install-asdf-tools:
	@echo -e "\n# installing asdf stuff\n"
	-asdf plugin add kubectl
	-asdf plugin add jq https://github.com/ryodocx/asdf-jq
	cat .tool-versions | xargs -L1 asdf install
	asdf reshim

.PHONY: shell-multitool
shell-multitool:
	@kubectl run -it --rm --restart=Never "shell-multitool-$${USER}" --image=praqma/network-multitool:alpine-extra -- bash

all: install-asdf-tools