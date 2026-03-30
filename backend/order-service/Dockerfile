FROM maven:3.9.6-eclipse-temurin-17 AS build
ARG NEXUS_PASSWORD
ENV NEXUS_PASSWORD=${NEXUS_PASSWORD}
WORKDIR /workspace
COPY settings.xml /tmp/settings-template.xml
RUN mkdir -p /root/.m2 && \
    awk '{gsub(/\$\{env\.NEXUS_PASSWORD\}/, ENVIRON["NEXUS_PASSWORD"]); print}' \
    /tmp/settings-template.xml > /root/.m2/settings.xml
COPY backend/pom.xml /pom.xml
COPY backend/order-service/pom.xml .
COPY backend/order-service/src ./src
RUN mvn -B clean package -DskipTests

FROM eclipse-temurin:17-jre
WORKDIR /app
RUN addgroup --system spring && adduser --system --ingroup spring spring
USER spring
COPY --from=build /workspace/target/order-service-*.jar app.jar
EXPOSE 8085
ENTRYPOINT ["java","-jar","/app/app.jar"]