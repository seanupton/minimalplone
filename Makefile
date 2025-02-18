# include Makefile config/scaffolding
include scaffolding.mk

.PHONY: all
all: build

# we want a simple way to get environment varaibles:
.env:  # .env exists, if not make a blank one
	if [ ! -f .env ]; then touch .env ; fi

# this allows us to consume such variables by sourcing .env-export
# in other steps:
#  (based on https://stackoverflow.com/a/44637188; modified for BSD sed) 
.env-export: .env
    sed -ne '/^export / {p;d;}; /.*=/ s/^/export / p' .env > .env-export

bin/pip:
	@echo "$(GREEN)==> Setup Virtual Env$(RESET)"
	python -m venv venv
	venv/bin/pip install -U "pip" "wheel" "cookiecutter" "mxdev"

instance/etc/zope.ini:	bin/pip .env-export
	@echo "$(GREEN)==> Install Plone and create instance$(RESET)"
	venv/bin/cookiecutter -f --no-input --config-file instance.yaml https://github.com/plone/cookiecutter-zope-instance --checkout 2.1.1
	env

.PHONY: build
build: instance/etc/zope.ini ## pip install Plone packages
	@echo "$(GREEN)==> Setup Build$(RESET)"
	venv/bin/mxdev -c mx.ini
	venv/bin/pip install -r requirements-mxdev.txt

.PHONY: start
start: ## Start a Plone instance on localhost:8080 in debug mode
	PYTHONWARNINGS=ignore venv/bin/runwsgi -d instance/etc/zope.ini

.PHONY: debug
debug: ## start Plone instance as interactive debug console
	PYTHONWARNINGS=ignore venv/bin/zconsole debug instance/etc/zope.conf

# -- scaffolding targets for this Makefile: --

.PHONY: help
help: .SHELLFLAGS:=-eu -o pipefail -O inherit_errexit -c
help: ## This help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

