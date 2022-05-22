#!/bin/bash
echo "Spinning up the nodes ..."

if [ "$ENVIRONMENT" == "production" ]; then
    echo "Deploying to production ..."
    for i in 1 2 3 4; do
        docker-machine create \
            --driver amazonec2 \
            --amazonec2-access-key $AMAZON_EC2_ACCESS_KEY \
            --amazonec2-secret-key $AMAZON_EC2_SECRET_KEY \
            --amazonec2-ami "ami-09042b2f6d07d164a" \
            --engine-install-url "https://test.docker.com/" \
            zanzi-server-node-$i
    done
else
    echo "Deploying to development ..."
    for i in 1 2 3 4; do
        docker-machine create \
            --driver virtualbox \
            --engine-install-url "https://releases.rancher.com/install-docker/19.03.9.sh" \
            zanzi-server-node-$i
    done
fi

echo "Nodes have been created ..."

echo "Initializing Swarm mode..."
docker-machine ssh zanzi-server-node-1 -- docker swarm init --advertise-addr $(docker-machine ip zanzi-server-node-1)

echo "Adding the nodes to the Swarm..."

TOKEN=$(docker-machine ssh zanzi-server-node-1 docker swarm join-token worker | grep token | awk '{ print $5 }')

for i in 2 3 4; do
    docker-machine ssh zanzi-server-node-$i \
        -- docker swarm join --token ${TOKEN} $(docker-machine ip zanzi-server-node-1):2377
done

echo "Creating secret ..."

eval $(docker-machine env zanzi-server-node-1)
echo $POSTGRES_USER | docker secret create POSTGRES_USER -
echo $POSTGRES_PASS | docker secret create POSTGRES_PASS -

echo "Deploying the Django microservice..."

docker stack deploy --compose-file=docker-compose-swarm.yml zanzi

echo "Create the DB table and apply the seed ..."

sleep 15
NODE=$(docker service ps -f "desired-state=running" --format "{{.Node}}" zanzi_web)
eval $(docker-machine env $NODE)
CONTAINER_ID=$(docker ps --filter name=zanzi_web --format "{{.ID}}")
docker container exec -it $CONTAINER_ID python manage.py recreate_db
docker container exec -it $CONTAINER_ID python manage.py seed_db

echo "Get the IP address ..."
eval $(docker-machine env zanzi-server-node-1)
docker-machine ip $(docker service ps -f "desired-state=running" --format "{{.Node}}" zanzi_nginx)
