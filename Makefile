REPONAME := monitoring
APPNAME := sql-agent

# If TAG is passed in, use that.  Otherwise, default to latest
TAG := $(if $(TAG),$(TAG),latest)
STAGE := $(if ${STAGE},${STAGE},staging)

# Retrieve current git branch and latest commit SHA.
BRANCH := $(shell git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')
SHORTSHA := $(shell git log --pretty=format:'%h' -n 1)
# If there are uncommitted changes, add "-dirty" to the tag.
DIRTY := $(if $(shell git status --porcelain --untracked-files=no),-dirty,)

include ~/.ibis/${STAGE}.env

## image: Build the Docker image
.PHONY: image
image:
	docker build --rm . -t '${REPONAME}/$(APPNAME):latest'
	docker tag ${REPONAME}/$(APPNAME):latest ${REPONAME}/$(APPNAME):$(TAG)
	docker tag ${REPONAME}/$(APPNAME):latest ${REPONAME}/$(APPNAME):$(BRANCH)
	docker tag ${REPONAME}/$(APPNAME):latest ${REPONAME}/$(APPNAME):$(BRANCH)-$(SHORTSHA)$(DIRTY)

.PHONY: tag
tag:
	docker tag ${REPONAME}/$(APPNAME):latest ${REPONAME}/$(APPNAME):$(TAG)

CMD := $(shell aws ecr get-login --region us-west-2 --no-include-email)
## registry-login: Log in to Amazon Cloud
.PHONY: registry-login
registry-login:
	@eval $(CMD)

## push-image: Push the image to Amazon ECR
.PHONY: push-image
push-image: image registry-login
	docker tag ${REPONAME}/$(APPNAME):$(TAG) \
		${AWS_ECR_BASE_ADDRESS}/${REPONAME}/$(APPNAME):$(TAG)
	docker push ${AWS_ECR_BASE_ADDRESS}/${REPONAME}/$(APPNAME):$(TAG)

	docker tag ${REPONAME}/$(APPNAME):$(BRANCH) \
		${AWS_ECR_BASE_ADDRESS}/${REPONAME}/$(APPNAME):$(BRANCH)
	docker push ${AWS_ECR_BASE_ADDRESS}/${REPONAME}/$(APPNAME):$(BRANCH)

	docker tag ${REPONAME}/$(APPNAME):$(BRANCH)-$(SHORTSHA)$(DIRTY) \
		${AWS_ECR_BASE_ADDRESS}/${REPONAME}/$(APPNAME):$(BRANCH)-$(SHORTSHA)$(DIRTY)
	docker push ${AWS_ECR_BASE_ADDRESS}/${REPONAME}/$(APPNAME):$(BRANCH)-$(SHORTSHA)$(DIRTY)

	docker tag ${REPONAME}/$(APPNAME):latest \
		${AWS_ECR_BASE_ADDRESS}/${REPONAME}/$(APPNAME):latest
	docker push ${AWS_ECR_BASE_ADDRESS}/${REPONAME}/$(APPNAME):latest


## targets: Show available targets
.PHONY: help targets
help targets:
	@echo "Available targets:"
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##/   /' | sort