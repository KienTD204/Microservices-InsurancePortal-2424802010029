using System;
using System.Threading.Tasks;
using DashboardService.DataAccess.Elastic;
using DashboardService.Domain;
using Xunit;

namespace DashboardService.Test;

[Collection("ElasticSearch in a container")]
public class PremiumPrecisionTest
{
    private readonly ElasticSearchInContainerFixture fixture;
    public PremiumPrecisionTest(ElasticSearchInContainerFixture fixture) => this.fixture = fixture;

    [Fact]
    public async Task Legacy_integer_mapping_is_copied_without_losing_source_cents_or_deleting_the_old_index()
    {
        var client = fixture.ElasticClient();
        await PolicyIndex.EnsureCreatedAsync(client);
        var repository = new ElasticPolicyRepository(client);
        var result = repository.GetTotalSales(new TotalSalesQuery("LEGACY", new DateTime(2034, 1, 1), new DateTime(2034, 12, 31)));
        Assert.True(client.Indices.Exists(PolicyIndex.LegacyName).Exists);
        Assert.Equal(1, result.Total.PoliciesCount);
        Assert.Equal(12.34m, result.Total.PremiumAmount);
    }

    [Fact]
    public void Monetary_cents_and_policy_idempotency_are_preserved_in_all_reports()
    {
        var repository = new ElasticPolicyRepository(fixture.ElasticClient());
        var from = new DateTime(2035, 1, 1);
        var to = new DateTime(2035, 1, 31);
        var policy = new PolicyDocument("decimal-regression", from, to, "Lab Test", "CENT", 123.45m, "decimal.agent");
        repository.Save(policy);
        repository.Save(policy);

        var total = repository.GetTotalSales(new TotalSalesQuery("CENT", from, to));
        Assert.Equal(1, total.Total.PoliciesCount);
        Assert.Equal(123.45m, total.Total.PremiumAmount);
        var agent = repository.GetAgentSales(new AgentSalesQuery("decimal.agent", "CENT", from, to));
        Assert.Equal(123.45m, agent.PerAgentTotal["decimal.agent"].PremiumAmount);
        var trend = repository.GetSalesTrend(new SalesTrendsQuery("CENT", from, to, TimeAggregationUnit.Month));
        Assert.Equal(123.45m, Assert.Single(trend.PeriodSales).Sales.PremiumAmount);
    }
}
