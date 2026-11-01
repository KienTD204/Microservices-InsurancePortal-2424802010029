FROM mcr.microsoft.com/dotnet/sdk:8.0.425
WORKDIR /src
COPY . .
RUN dotnet build DotNetMicroservicesPoc.sln -c Release --nologo > /tmp/lab7-build-linux.txt 2>&1 || (cat /tmp/lab7-build-linux.txt && exit 1)
ENV ASPNETCORE_ENVIRONMENT=Development \
    Logging__EventLog__LogLevel__Default=None \
    Eureka__Client__ShouldRegisterWithEureka=false \
    Eureka__Client__ShouldFetchRegistry=false \
    TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal
CMD ["bash", "scripts/verify-lab7-container.sh"]
