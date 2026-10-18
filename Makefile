APP_NAME:=technical-test-simple-server
VERSION:=2.0.0
DOCKER_USERNAME:=mirzarama27

test:
	go test -v ./...

build:
	docker build --build-arg APP_VERSION=${VERSION} -t ${DOCKER_USERNAME}/${APP_NAME}:${VERSION} .
# 	docker build --target builder --output type=local,dest=./releases/${VERSION}/ .

run:
	mkdir -p state
	docker run -d -v "./releases:/releases" -p 8080:8080 --name $(APP_NAME) ${DOCKER_USERNAME}/${APP_NAME}:${VERSION}
	printf '%s\n' "${VERSION}" > "./state/current.txt"

release:
	mkdir -p releases/$(VERSION)
	docker run --restart=always -d --name release-container ${DOCKER_USERNAME}/$(APP_NAME):$(VERSION)
	docker cp release-container:/app/server ./releases/$(VERSION)/server
	docker rm -f release-container

update:
	./scripts/update.sh ${VERSION}

rollback:
	./scripts/rollback.sh

push:
	docker push ${DOCKER_USERNAME}/${APP_NAME}:${VERSION} 

pull:
	docker pull ${DOCKER_USERNAME}/${APP_NAME}:${VERSION}

restart:
	docker restart ${APP_NAME}:${VERSION}

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




