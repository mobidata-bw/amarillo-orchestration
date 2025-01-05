-include .env .env.local

DOCKER_COMPOSE = docker compose --env-file .env --env-file .env.local

.DEFAULT_GOAL := show-help

.PHONY: init
init:
	mkdir -p var/graphhopper
	mkdir -p var/amarillo/data/agencyconf
	mkdir -p var/amarillo-test/data/agencyconf
	mkdir -p var/amarillo/stops
	touch .env.local

.PHONY: stops
## Download stops to be used to snap origin/destination to and use as potential changes
stops:
	wget -O var/amarillo/stops/stops_zhv.csv https://data.mfdz.de/mfdz/stops/stops_zhv.csv
	wget -O var/amarillo/stops/parkings_osm.csv https://data.mfdz.de/mfdz/stops/parkings_osm.csv

# Download osm file to be used as input for the graphhopper routing graph
var/graphhopper/$(OSM_FILE):
	wget -N $(OSM_DOWNLOAD_PATH)/$(OSM_FILE) -O var/graphhopper/$(OSM_FILE)

# Build the graphhoppper routing graph, replace the old one and restart graphhopper
var/graphhopper/default-gh/edges: var/graphhopper/$(OSM_FILE)
	$(DOCKER_COMPOSE) run --rm graphhopper --import -i /data/$(OSM_FILE) -o /data/new-gh/
	# replace the existing routing data
	rm -fr var/graphhopper/default-gh ; mv var/graphhopper/new-gh var/graphhopper/default-gh
	# re/start the service as appropriate
	$(DOCKER_COMPOSE) restart graphhopper || $(DOCKER_COMPOSE) up -d graphhopper

.PHONY: rebuild-graph
## Rebuild graphhopper graph
rebuild-graph: init var/graphhopper/default-gh/edges

.PHONY: docker-pull
## Pull all images or only the containers specified by SERVICE (e.g. `make docker-pull SERVICE=graphhopper`)
docker-pull:
	$(DOCKER_COMPOSE) pull $(SERVICE)

.PHONY: docker-up-detached
## Start containers in background (or recreate containers while they are running attached to another terminal). Supports starting or
## restarting by SERVICE (e.g. `make docker-up-detached SERVICE=graphhopper`)
docker-up-detached: init
	$(DOCKER_COMPOSE) up -d

.PHONY: docker-down
## Stops and removes all or only the containers specified by SERVICE (e.g. `make docker-down SERVICE=graphhopper`)
docker-down:
	$(DOCKER_COMPOSE) down $(SERVICE)

.PHONY: show-todays-offers
## Lists todays offers (from amarillo's and amarilo-test's data/carpool folder)
show-todays-offers:
	grep -rl "\"lastUpdated\":\"`date '+%Y-%m-%d'`" var/amarillo/data/carpool | sort
	grep -rl "\"lastUpdated\":\"`date '+%Y-%m-%d'`" var/amarillo-test/data/carpool | sort

# See <https://gist.github.com/klmr/575726c7e05d8780505a> for explanation.
.PHONY: show-help
show-help:
	@echo "$$(tput setaf 2)Available rules:$$(tput sgr0)";sed -ne"/^## /{h;s/.*//;:d" -e"H;n;s/^## /---/;td" -e"s/:.*//;G;s/\\n## /===/;s/\\n//g;p;}" ${MAKEFILE_LIST}|awk -F === -v n=$$(tput cols) -v i=4 -v a="$$(tput setaf 6)" -v z="$$(tput sgr0)" '{printf"- %s%s%s\n",a,$$1,z;m=split($$2,w,"---");l=n-i;for(j=1;j<=m;j++){l-=length(w[j])+1;if(l<= 0){l=n-i-length(w[j])-1;}printf"%*s%s\n",-i," ",w[j];}}'