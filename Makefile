# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
.PHONY: docs help test

# Use bash for inline if-statements in arch_patch target
SHELL:=bash
# OWNER:=jupyter
OWNER:=sparkpost
ARCH:=$(shell uname -m)
DIFF_RANGE?=master...HEAD

# Need to list the images in build dependency order
ifeq ($(ARCH),ppc64le)
ALL_STACKS:=base-notebook
else
ALL_STACKS:=base-notebook \
	minimal-notebook \
	r-notebook \
	scipy-notebook \
	tensorflow-notebook \
	datascience-notebook \
	pyspark-notebook \
	all-spark-notebook
endif

ALL_IMAGES:=$(ALL_STACKS)

help:
# http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
	@echo "jupyter/docker-stacks"
	@echo "====================="
	@echo "Replace % with a stack directory name (e.g., make build/minimal-notebook)"
	@echo
	@grep -E '^[a-zA-Z0-9_%/-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

arch_patch/%: ## apply hardware architecture specific patches to the Dockerfile
	@if [ -e ./$(notdir $@)/Dockerfile.$(ARCH).patch ]; then \
		if [ -e ./$(notdir $@)/Dockerfile.orig ]; then \
               		cp -f ./$(notdir $@)/Dockerfile.orig ./$(notdir $@)/Dockerfile;\
		else\
                	cp -f ./$(notdir $@)/Dockerfile ./$(notdir $@)/Dockerfile.orig;\
		fi;\
		patch -f ./$(notdir $@)/Dockerfile ./$(notdir $@)/Dockerfile.$(ARCH).patch; \
	fi

build/%: DARGS?=--build-arg BASE_ORGANIZATION=$(OWNER)
build/%: ## build the latest image for a stack
	docker build $(DARGS) --rm --force-rm -t $(OWNER)/$(notdir $@):latest ./$(notdir $@)
	docker tag $(OWNER)/$(notdir $@):latest $(OWNER)/$(notdir $@):$$(git rev-parse HEAD)

push/%:
	docker push $(OWNER)/$(notdir $@)

build-all: $(foreach I,$(ALL_IMAGES),arch_patch/$(I) build/$(I) ) ## build all stacks
build-test-all: $(foreach I,$(ALL_IMAGES),arch_patch/$(I) build/$(I) test/$(I) ) ## build and test all stacks
push-all: $(foreach I,$(ALL_IMAGES),arch_patch/$(I) build/$(I) push/$(I)) ## build, test and push all stacks

dev/%: ARGS?=
dev/%: DARGS?=
dev/%: PORT?=8888
dev/%: ## run a foreground container for a stack
	docker run -it --rm -p $(PORT):8888 $(DARGS) $(OWNER)/$(notdir $@) $(ARGS)

dev-env: ## install libraries required to build docs and run tests
	pip install -r requirements-dev.txt

docs: ## build HTML documentation
	make -C docs html

n-docs-diff: ## number of docs/ files changed since branch from master
	@git diff --name-only $(DIFF_RANGE) -- docs/ ':!docs/locale' | wc -l | awk '{print $$1}'


n-other-diff: ## number of files outside docs/ changed since branch from master
	@git diff --name-only $(DIFF_RANGE) -- ':!docs/' | wc -l | awk '{print $$1}'

tx-en: ## rebuild en locale strings and push to master (req: GH_TOKEN)
	@git config --global user.email "travis@travis-ci.org"
	@git config --global user.name "Travis CI"
	@git checkout master

	@make -C docs clean gettext
	@cd docs && sphinx-intl update -p _build/gettext -l en

	@git add docs/locale/en
	@git commit -m "[ci skip] Update en source strings (build: $$TRAVIS_JOB_NUMBER)"

	@git remote add origin-tx https://$${GH_TOKEN}@github.com/jupyter/docker-stacks.git
	@git push -u origin-tx master


test/%: ## run tests against a stack
	@TEST_IMAGE="$(OWNER)/$(notdir $@)" pytest test

test/base-notebook: ## test supported options in the base notebook
	@TEST_IMAGE="$(OWNER)/$(notdir $@)" pytest test base-notebook/test
