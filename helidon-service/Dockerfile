FROM container-registry.oracle.com/java/jdk:26 AS build
WORKDIR /src
COPY pom.xml ./
COPY src ./src
RUN mvn -B -DskipTests package

FROM container-registry.oracle.com/java/jre:26
WORKDIR /app
COPY --from=build /src/target/go-java-go-helidon.jar /app/go-java-go-helidon.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/go-java-go-helidon.jar"]

