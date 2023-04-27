# Opentourney local repo

This repo serves as a way to run the opentourney platform locally. If you want to use the official app (gcp and aws) the urls are:

- http://opentourney.duckdns.org/ (production branch)
- http://dev-opentourney.duckdns.org/ (dev branch)
- http://api-opentourney.duckdns.org/ (production branch)
- http://api-dev-opentourney.duckdns.org/ (dev branch)

** Slow, because of micro container optimized instances

## Steps to run

### Create an dev.env file for the api (in the same folder as the example)

`docker compose build`

`docker compose up -d`

### Apply the migrations

`cd opentourney-api`

`npm install`

`npm run migrate:dev up`



