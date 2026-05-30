FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY target/{{PROJECT_NAME}}-*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
