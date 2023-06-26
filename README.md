# Opentourney local repo

This repo serves as a way to run the opentourney platform locally. If you want to use the official app (gcp and aws) the urls are:

https://broadvision.eu.org/

** Slow, because of micro container optimized instances

## Steps to run

### Create an dev.env file for the api (in the same folder as the example)

`docker compose build`

`docker compose up -d`

### Apply the migrations

`cd opentourney-api`

`npm install`

`npm run migrate:dev up`

##
- k8s-cloud --> fetches the images from Docker Hub
- k8s-local --> fetcher the images from the local docker environment 
### To run the cluster locally you should:

`docker compose build `

`eval $(minikube docker-env)`

`kubectl apply -f k8s-local/`

- apply the migrations


### To run the cluster on the cloud you should:

- terraform apply

- apply the migrations