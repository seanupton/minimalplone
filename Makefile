# include Makefile config/scaffolding
include scaffolding.mk

_cwd := $(shell pwd)

.PHONY: all
all: build

bin/pip:
	@echo "$(GREEN)==> Setup Virtual Env$(RESET)"
	python -m venv venv
	venv/bin/pip install -U "pip" "wheel" "cookiecutter" "mxdev"

instance/etc/zope.ini:	bin/pip
	@echo "$(GREEN)==> Install Plone and create instance$(RESET)"
	venv/bin/cookiecutter -f --no-input --config-file instance.yaml https://github.com/plone/cookiecutter-zope-instance --checkout 2.1.1
	env

.PHONY: build
build: zeo instance/etc/zope.ini ## pip install Plone packages
	@echo "$(GREEN)==> Setup Build$(RESET)"
	venv/bin/mxdev -c mx.ini
	venv/bin/pip install -r requirements-mxdev.txt

zeo/var/blobstorage:
	@echo "$(GREEN)==> Create $@ directory for BLOB storage$(RESET)"
	mkdir -p zeo/var/blobstorage

.PHONY: zeo
zeo: zeo/var/blobstorage ## install zeo server
	@echo "$(GREEN)==> Install ZEO server$(RESET)"
	venv/bin/mkzeoinstance zeo/ 127.0.0.1:8100 -b zeo/var/blobstorage

.PHONY: zeostart
zeostart: ## start zeo server in background
	# get pid as (simply expanded) make var
	$(eval zeopid := $(strip $(shell ps -Aef | grep runzeo | grep $(_cwd) | grep -v ps..Aef | tr -s ' ' | cut -d' ' -f3 | head -n1)))
	# shell conditional runs only if NO pid (ZEO is not already running):
	if [ -z "$(zeopid)" ]; then \
	    echo "$(YELLOW)==> Starting ZEO server$(RESET)"; \
	    (PYTHONWARNINGS=ignore venv/bin/runzeo -C zeo/etc/zeo.conf & ); \
	else \
		echo "ZEO is already running."; \
	fi 

.PHONY: zeostop
zeostop: ## stop zeo server, if running
	# get pid as (simply expanded) make var
	$(eval zeopid := $(strip $(shell ps -Aef | grep runzeo | grep $(_cwd) | grep -v ps..Aef | tr -s ' ' | cut -d' ' -f3 | head -n1)))
	# shell conditional runs only if there is a pid (ZEO is running):
	if [ -n "$(zeopid)" ]; then \
	    echo "$(YELLOW)==> Stopping ZEO server at PID $(zeopid)$(RESET)"; \
	    kill -s USR1 $(zeopid); \
	else \
		echo "ZEO is not running."; \
	fi

.PHONY: run
run: zeostart ## Start, foreground Plone instance for development
	PYTHONWARNINGS=ignore venv/bin/runwsgi -d instance/etc/zope.ini

.PHONE: start
start: run ## 'start' is an alias to 'run'

.PHONY: debug
debug: ## start Plone instance as interactive debug console
	PYTHONWARNINGS=ignore venv/bin/zconsole debug instance/etc/zope.conf

# -- scaffolding targets for this Makefile: --

.PHONY: help
help: .SHELLFLAGS:=-eu -o pipefail -O inherit_errexit -c
help: ## This help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

