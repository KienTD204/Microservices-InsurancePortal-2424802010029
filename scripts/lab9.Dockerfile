# Lab 9 - one image that holds the Release build of the whole solution.
# Every microservice container in scripts/lab9.docker.yml runs from this image with its own working directory.
FROM mcr.microsoft.com/dotnet/sdk:8.0.425
WORKDIR /src
COPY . .
RUN dotnet build DotNetMicroservicesPoc.sln -c Release --nologo -v minimal > /tmp/lab9-build-linux.txt 2>&1 \
    || (cat /tmp/lab9-build-linux.txt && exit 1)
ENV ASPNETCORE_ENVIRONMENT=docker \
    DOTNET_ENVIRONMENT=docker \
    Logging__EventLog__LogLevel__Default=None
