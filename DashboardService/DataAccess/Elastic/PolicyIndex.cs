using System;
using System.Threading.Tasks;
using System.Text.Json;
using Elastic.Clients.Elasticsearch;
using Elastic.Clients.Elasticsearch.Mapping;
using Elastic.Transport;

namespace DashboardService.DataAccess.Elastic;

public static class PolicyIndex
{
    public const string Name = "policy_lab_stats_v2";
    public const string LegacyName = "policy_lab_stats";

    public static async Task EnsureCreatedAsync(ElasticsearchClient client)
    {
        if (!(await client.Indices.ExistsAsync(Name)).Exists)
        {
            var created = await client.Indices.CreateAsync(Name, index => index.Mappings(new TypeMapping
            {
                Properties = new Properties
                {
                    ["totalPremium"] = new ScaledFloatNumberProperty { ScalingFactor = 100 }
                }
            }));
            if (!created.IsValidResponse)
                throw new InvalidOperationException("Cannot create the dashboard index with a monetary field mapping.");
        }

        // The old dynamic mapping may be 'long', which truncates premium cents.
        // Reindex from _source so the original decimal values are retained, and keep the old index intact.
        if ((await client.Indices.ExistsAsync(LegacyName)).Exists)
        {
            // 8.9.3 serializes Destination.OpType as an object; send the REST string value explicitly.
            var migrated = await client.Transport.RequestAsync<StringResponse>(global::Elastic.Transport.HttpMethod.POST,
                "/_reindex", PostData.Serializable(new
                {
                    source = new { index = LegacyName },
                    dest = new { index = Name, op_type = "create" },
                    conflicts = "proceed"
                }), new ReindexRequestParameters { WaitForCompletion = true, Refresh = true });
            if (!migrated.ApiCallDetails.HasSuccessfulStatusCode)
                throw new InvalidOperationException("Cannot copy legacy dashboard policies to the monetary index.");
            using var result = JsonDocument.Parse(migrated.Body);
            if (result.RootElement.GetProperty("timed_out").GetBoolean() ||
                result.RootElement.GetProperty("failures").GetArrayLength() > 0)
                throw new InvalidOperationException("Dashboard index migration did not finish successfully.");
        }
    }
}
