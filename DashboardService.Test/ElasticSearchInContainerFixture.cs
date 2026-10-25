using System;
using System.Threading.Tasks;
using DashboardService.DataAccess.Elastic;
using DashboardService.Domain;
using DotNet.Testcontainers.Builders;
using Elastic.Clients.Elasticsearch;
using Elastic.Clients.Elasticsearch.Mapping;
using Testcontainers.Elasticsearch;
using Xunit;

namespace DashboardService.Test;

public class ElasticSearchInContainerFixture : IAsyncLifetime
{
    private readonly ElasticsearchContainer testContainer = new ElasticsearchBuilder()
        .WithImage("docker.elastic.co/elasticsearch/elasticsearch:8.9.2")
        .WithEnvironment("discovery.type", "single-node")
        .WithEnvironment("xpack.security.enabled", "false")
        .WithEnvironment("ES_JAVA_OPTS", "-Xms512m -Xmx512m")
        .WithPortBinding(9200, true)
        .WithWaitStrategy(Wait.ForUnixContainer().UntilHttpRequestIsSucceeded(request => request.ForPort(9200).ForPath("/")))
        .Build();
    
    public async Task InitializeAsync()
    {
        await testContainer.StartAsync();
        var client = ElasticClient();
        // Reproduce the old automatic integer mapping while retaining decimals in _source.
        await client.Indices.CreateAsync(PolicyIndex.LegacyName, index => index.Mappings(new TypeMapping
        {
            Properties = new Properties { ["totalPremium"] = new LongNumberProperty() }
        }));
        await client.IndexAsync(new PolicyDocument("legacy-decimal", new System.DateTime(2034, 1, 1),
            new System.DateTime(2034, 12, 31), "Legacy Test", "LEGACY", 12.34m, "legacy.agent"),
            index => index.Index(PolicyIndex.LegacyName).Id("legacy-decimal").Refresh(Refresh.True));
        await PolicyIndex.EnsureCreatedAsync(ElasticClient());
        InsertData();
    }

    public Task DisposeAsync()
    {
        return testContainer.DisposeAsync().AsTask();
    }
    

    public ElasticsearchClient ElasticClient()
    {
        var endpoint = new Uri($"http://{testContainer.Hostname}:{testContainer.GetMappedPublicPort(9200)}");
        var connectionSettings = new ElasticsearchClientSettings(endpoint)
            .DefaultMappingFor<PolicyDocument>(m =>
                m.IndexName(PolicyIndex.Name).IdProperty(d => d.Number));
        return new ElasticsearchClient(connectionSettings);
    }

    private void InsertData()
    {
        var policyRepo = new ElasticPolicyRepository(ElasticClient());
        //products TRI,HSI,FAI,CAR

        var agent = "jimmy.solid";
        //january-2020
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("TRI")
                .WithDates("2020-01-01", "2020-12-31")
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("TRI")
                .WithDates("2020-01-15", "2021-01-14")
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("HSI")
                .WithDates("2020-01-15", "2021-01-14")
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("FAI")
                .WithDates("2020-01-15", "2021-01-14")
                .WithPremium(150M)
                .Build()
        );
        //feb-2020
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("TRI")
                .WithDates("2020-02-01", "2021-01-31")
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("HSI")
                .WithDates("2020-02-15", "2021-02-14")
                .WithPremium(80M)
                .Build()
        );
        //march-2020
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("TRI")
                .WithDates("2020-03-01", "2021-02-28")
                .WithPremium(50M)
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("TRI")
                .WithDates("2020-03-15", "2021-03-14")
                .WithPremium(25M)
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("TRI")
                .WithDates("2020-03-15", "2021-03-14")
                .WithPremium(15M)
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("HSI")
                .WithDates("2020-03-15", "2021-03-14")
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("FAI")
                .WithDates("2020-03-15", "2021-03-14")
                .WithPremium(250M)
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("FAI")
                .WithDates("2020-03-15", "2021-03-14")
                .WithPremium(250M)
                .Build()
        );

        //agent danny.solid
        agent = "danny.solid";
        //january-2020
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("TRI")
                .WithDates("2020-01-01", "2020-12-31")
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("HSI")
                .WithDates("2020-01-01", "2020-12-31")
                .WithPremium(50M)
                .Build()
        );
        //feb-2020
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("TRI")
                .WithDates("2020-02-01", "2021-01-31")
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("HSI")
                .WithDates("2020-02-01", "2021-01-31")
                .WithPremium(25M)
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("FAI")
                .WithDates("2020-02-01", "2021-01-31")
                .WithPremium(50M)
                .Build()
        );
        //march-2020
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("TRI")
                .WithDates("2020-03-01", "2021-02-28")
                .WithPremium(50M)
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("HSI")
                .WithDates("2020-03-01", "2021-02-28")
                .WithPremium(50M)
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("HSI")
                .WithDates("2020-03-01", "2021-02-28")
                .WithPremium(50M)
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("FAI")
                .WithDates("2020-03-01", "2021-02-28")
                .WithPremium(25M)
                .Build()
        );
        policyRepo.Save
        (
            PolicyDocumentBuilder.Create()
                .WithAgent(agent)
                .WithProduct("FAI")
                .WithDates("2020-03-01", "2021-02-28")
                .WithPremium(25M)
                .Build()
        );
    }
}

[CollectionDefinition("ElasticSearch in a container")]
public class ElasticSearchInContainerCollection : ICollectionFixture<ElasticSearchInContainerFixture>
{
}
