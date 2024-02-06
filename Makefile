-include .env .env.local

DOCKER_COMPOSE = docker compose --env-file .env --env-file .env.local
VAR_DIR = var

.PHONY: init
init:
	mkdir -p var/graphhopper
	mkdir -p var/amarillo/data/agencyconf
	mkdir -p var/amarillo/stops
	touch .env.local

# Download stops to be used to snap origin/destination to and use as potential changes
.PHONY: stops
stops:
	wget -O $(VAR_DIR)/amarillo/stops/stops_zhv.csv https://data.mfdz.de/mfdz/stops/stops_zhv.csv
	wget -O $(VAR_DIR)/amarillo/stops/parkings_osm.csv https://data.mfdz.de/mfdz/stops/parkings_osm.csv

# Download osm file to be used as input for the graphhopper routing graph
var/graphhopper/$(OSM_FILE):
	wget -N $(OSM_DOWNLOAD_PATH)/$(OSM_FILE) -O var/graphhopper/$(OSM_FILE)

# Build the graphhoppper routing graph, replace the old one and restart graphhopper
var/graphhopper/default-gh/edges: $(VAR_DIR)/graphhopper/$(OSM_FILE)
	$(DOCKER_COMPOSE) run --rm graphhopper --import -i /data/$(OSM_FILE) -o /data/new-gh/
	# replace the existing routing data
	rm -fr $(VAR_DIR)/graphhopper/default-gh ; mv $(VAR_DIR)/graphhopper/new-gh $(VAR_DIR)/graphhopper/default-gh
	# re/start the service as appropriate
	$(DOCKER_COMPOSE) restart graphhopper || $(DOCKER_COMPOSE) up -d graphhopper

# Rebuild graphhopper graph
.PHONY: rebuild-graph
rebuild-graph: init var/graphhopper/default-gh/edges

# Pull all images or only the containers specified by SERVICE (e.g. `make docker-pull SERVICE=graphhopper`)
.PHONY: docker-pull
docker-pull:
	$(DOCKER_COMPOSE) pull $(SERVICE)

# Start containers in background (or recreate containers while they are running attached to another terminal). Supports starting or
# restarting by SERVICE (e.g. `make docker-up-detached SERVICE=graphhopper`)
.PHONY: docker-up-detached
docker-up-detached: init
	$(DOCKER_COMPOSE) up -d