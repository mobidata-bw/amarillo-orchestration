-include .env .env.local

DOCKER_COMPOSE = docker compose --env-file .env --env-file .env.local
VAR_DIR = var

.PHONY: init
init:
	mkdir -p var/graphhopper
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

rebuild-graph: init var/graphhopper/default-gh/edges

docker-up-detached:
	$(DOCKER_COMPOSE) up -d