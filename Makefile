APP_NAME:=technical-test-simple-server
VERSION:=1.0.1
DOCKER_USERNAME:=mirzarama27

build:
	docker build --build-arg APP_VERSION=${VERSION} -t ${DOCKER_USERNAME}/${APP_NAME}:${VERSION} .

run:
	mkdir -p state
	docker run -d \
		-v "$(CURDIR)/releases:/releases" \
		-p 8080:8080 \
		--name $(APP_NAME) \
		$(APP_NAME):$(VERSION)

release:
	mkdir -p releases
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
		go build \
		-ldflags="-X main.version=$(VERSION)" \
		-o releases/$(VERSION)/server ./cmd/app

update:
	./scripts/update.sh ${VERSION}

push:
	docker push ${DOCKER_USERNAME}/${APP_NAME}:${VERSION} 

pull:
	docker pull ${DOCKER_USERNAME}/${APP_NAME}:${VERSION}

restart:
	docker restart ${APP_NAME}:${VERSION}

rollback:
	./scripts/rollback.sh

down:
	docker stop ${APP_NAME}
	docker rm ${APP_NAME}

logs:
	docker logs -f ${APP_NAME}


health:
	./scripts/health-check.sh
# 	curl http://localhost:8080/




