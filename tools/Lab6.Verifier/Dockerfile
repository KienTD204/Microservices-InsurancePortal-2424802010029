FROM mcr.microsoft.com/dotnet/sdk:8.0.425
WORKDIR /src
COPY . .
RUN dotnet build DotNetMicroservicesPoc.sln -c Release --nologo > /tmp/lab6-build-linux.txt 2>&1 || (cat /tmp/lab6-build-linux.txt && exit 1)
ENV ASPNETCORE_ENVIRONMENT=Development \
    Logging__EventLog__LogLevel__Default=None \
    Eureka__Client__ServiceUrl=http://eureka-server:8761/eureka/ \
    Eureka__Instance__HostName=lab6 \
    ConnectionStrings__ElasticSearchConnection=http://elasticsearch:9200 \
    RabbitMqOptions__Host=rabbit \
    LAB6_EUREKA_URL=http://eureka-server:8761 \
    LAB6_RABBITMQ_CONNECTION="host=rabbit;port=5672;username=guest;password=guest" \
    TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal
CMD ["bash", "scripts/start-lab6-container.sh"]
