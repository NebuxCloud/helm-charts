# Helpers
IS_DARWIN := $(filter Darwin,$(shell uname -s))

define set_env
	sed $(if $(IS_DARWIN),-i "",-i) -e "s/^#*\($(1)=\).*/$(if $(2),,#)\1$(2)/" .env
endef

EXEC := docker compose exec -T main
EXEC_TTY := docker compose exec main

# Environment recipes
.PHONY: default
default: init up

.PHONY: init
init:
	test -f .env || cp .env.example .env
	$(call set_env,USER_ID,$(shell id -u))
	$(call set_env,USER_NAME,$(shell whoami))

.PHONY: set-env
set-env: init
	$(call set_env,$(KEY),$(VALUE))

.PHONY: up
up:
	DOCKER_BUILDKIT=1 docker compose up -d --build

.PHONY: down
down:
	docker compose down

.PHONY: shell
shell:
	$(EXEC_TTY) zsh

# Application recipes
