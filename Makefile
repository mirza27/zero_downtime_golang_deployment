APP_NAME:=technical-test-simple-server
VERSION:=2.0.2
COMMIT_HASH:=$(shell git rev-parse --short HEAD 2>/dev/null || echo "dev")
IMAGE_TAG:=$(VERSION)-$(COMMIT_HASH)
DOCKER_USERNAME:=mirzarama27

test:
	go test -v ./...

build:
	docker build --build-arg APP_VERSION=${IMAGE_TAG} -t ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG} .
# 	docker build --target builder --output type=local,dest=./releases/${IMAGE_TAG}/ .

run:
	mkdir -p state
	docker run -d -v "./releases:/releases" -p 8080:8080 --name $(APP_NAME) ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}
	printf '%s\n' "${IMAGE_TAG}" > "./state/current.txt"

release:
	mkdir -p releases/$(IMAGE_TAG)
	docker run --restart=always -d --name release-container ${DOCKER_USERNAME}/$(APP_NAME):$(IMAGE_TAG)
	docker cp release-container:/app/server ./releases/$(IMAGE_TAG)/server
	docker rm -f release-container

update:
	./scripts/update.sh ${IMAGE_TAG}

rollback:
	./scripts/rollback.sh

push:
	docker push ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}

pull:
	docker pull ${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}

restart:
	docker restart ${APP_NAME}:${IMAGE_TAG}

down:
	docker stop ${APP_NAME}
	docker rm ${APP_NAME}

logs:
	docker logs -f ${APP_NAME}


health:
	./scripts/health-check.sh
# 	curl http://localhost:8080/

test-reload:
	exec ./scripts/test.sh > ./scripts/test2.log


.PHONY: test build run release update rollback push pull restart down logs health test-reload




