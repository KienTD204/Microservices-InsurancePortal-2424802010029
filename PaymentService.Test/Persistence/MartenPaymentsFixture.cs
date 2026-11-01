using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using PaymentService.DataAccess.Marten;
using Testcontainers.PostgreSql;
using Xunit;

namespace PaymentService.Tests.Persistence;

public sealed class MartenPaymentsFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer postgres = new PostgreSqlBuilder()
        .WithImage("postgres:16")
        .WithDatabase("lab7_payments_test")
        .WithUsername("lab7_test")
        .WithPassword("lab7_test")
        .Build();

    public ServiceProvider CreateServices()
    {
        var services = new ServiceCollection();
        services.AddMarten(postgres.GetConnectionString());
        return services.BuildServiceProvider();
    }

    public Task InitializeAsync() => postgres.StartAsync();

    public Task DisposeAsync() => postgres.DisposeAsync().AsTask();
}
