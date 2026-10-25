using System;
using DashboardService.Domain;
using Elastic.Clients.Elasticsearch;
using Microsoft.Extensions.DependencyInjection;

namespace DashboardService.DataAccess.Elastic;

public static class NestInstaller
{
    public static IServiceCollection AddElasticSearch(this IServiceCollection services, string cnString)
    {
        services.AddSingleton(typeof(ElasticsearchClient), svc => CreateElasticClient(cnString));
        services.AddScoped(typeof(IPolicyRepository), typeof(ElasticPolicyRepository));
        return services;
    }

    private static ElasticsearchClient CreateElasticClient(string cnString)
    {
        var connectionSettings = new ElasticsearchClientSettings(new Uri(cnString))
            .DefaultMappingFor<PolicyDocument>(m =>
                m.IndexName(PolicyIndex.Name).IdProperty(d => d.Number));
        return new ElasticsearchClient(connectionSettings);
    }
}
