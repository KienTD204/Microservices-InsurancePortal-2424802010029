#!/usr/bin/env bash
set -euo pipefail
cd /src
mkdir -p submission/lab6/evidence/tests-linux
cp /tmp/lab6-build-linux.txt submission/lab6/evidence/solution-build-linux.txt
for project in AuthService.Test ProductService.Test PricingService.Test PolicyService.Test PaymentService.Test DashboardService.Test PricingService.IntegrationTest; do
  Eureka__Client__ShouldRegisterWithEureka=false Eureka__Client__ShouldFetchRegistry=false \
    dotnet test "$project/$project.csproj" -c Release --no-build --no-restore --logger "trx;LogFileName=$project.trx" --results-directory submission/lab6/evidence/tests-linux -- RunConfiguration.TreatNoTestsAsError=true
done
for attempt in $(seq 1 60); do
  registry="$(curl -fsS -H 'Accept: application/json' "$LAB6_EUREKA_URL/eureka/apps" || true)"
  if [[ "$registry" == *PRODUCTSERVICE* && "$registry" == *DASHBOARDSERVICE* ]]; then break; fi
  sleep 2
done
dotnet tools/Lab6.Verifier/bin/Release/net8.0/Lab6.Verifier.dll submission/lab6/evidence/runtime-verification.json
