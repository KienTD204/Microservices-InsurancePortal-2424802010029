#!/usr/bin/env bash
set -euo pipefail
cd /src
mkdir -p submission/lab7/evidence/tests-linux
cp /tmp/lab7-build-linux.txt submission/lab7/evidence/solution-build-linux.txt
for project in AuthService.Test ProductService.Test PricingService.Test PolicyService.Test PaymentService.Test DashboardService.Test PricingService.IntegrationTest; do
  dotnet test "$project/$project.csproj" -c Release --no-build --no-restore \
    --logger "trx;LogFileName=$project.trx" \
    --results-directory submission/lab7/evidence/tests-linux \
    -- RunConfiguration.TreatNoTestsAsError=true
done
