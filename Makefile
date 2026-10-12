## @file Makefile
## @brief Orchestrates the Inception stack via Docker Compose.
## @note This Makefile does not build anything by itself: it only wraps
##       `docker compose`, which reads srcs/docker-compose.yml, which in
##       turn points to the Dockerfiles under srcs/requirements/.

NAME     = inception
LOGIN    = vinda-si
DATA_DIR = /home/$(LOGIN)/data
COMPOSE  = docker compose -f srcs/docker-compose.yml

## @brief Default target: prepare host data dirs, then build and start.
all: up

up: data_dirs
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

## @brief Bind-mount targets required by docker-compose.yml's volumes.
data_dirs:
	mkdir -p $(DATA_DIR)/wordpress
	mkdir -p $(DATA_DIR)/mariadb

## @brief Stop containers and remove them plus this project's local images/volumes.
clean: down
	$(COMPOSE) down -v --rmi local

## @brief clean + delete the data persisted on the host (irreversible).
fclean: clean
	rm -rf $(DATA_DIR)

re: fclean all

.PHONY: all up down stop start restart logs ps data_dirs clean fclean re
