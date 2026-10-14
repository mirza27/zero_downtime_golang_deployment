APP_NAME:=technical-test-simple-server
VERSION:=1.0.0


build:
	docker build --build-arg APP_VERSION=${VERSION} -t ${APP_NAME}:${VERSION} .


run:
	docker run -d -v ./release:/app/release -p 8080:8080 --name ${APP_NAME} ${APP_NAME}:${VERSION}


down:
	docker stop ${APP_NAME}
	docker rm ${APP_NAME}


logs:
	docker logs -f ${APP_NAME}


test:
	curl http://localhost:8080/




