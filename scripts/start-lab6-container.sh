#!/usr/bin/env bash
set -euo pipefail
mkdir -p /tmp/lab6-logs
pids=()
trap 'kill "${pids[@]}" 2>/dev/null || true; wait || true' EXIT TERM INT
for item in AuthService:6060 ProductService:5030 ChatService:4099 DashboardService:5035 AgentPortalApiGateway:8099; do
  service="${item%:*}"
  port="${item#*:}"
  register=true
  if [ "$service" = AgentPortalApiGateway ]; then register=false; fi
  (
    cd "/src/$service"
    ASPNETCORE_URLS="http://0.0.0.0:$port" Eureka__Instance__Port="$port" Eureka__Client__ShouldRegisterWithEureka="$register" \
      dotnet "bin/Release/net8.0/$service.dll" --urls "http://0.0.0.0:$port"
  ) >"/tmp/lab6-logs/$service.log" 2>&1 &
  pids+=("$!")
done
wait -n "${pids[@]}"
