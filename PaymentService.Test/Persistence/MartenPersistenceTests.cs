using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Marten;
using Microsoft.Extensions.DependencyInjection;
using PaymentService.Api.Queries;
using PaymentService.Domain;
using PaymentService.Init;
using PaymentService.Listeners;
using PaymentService.Queries;
using PolicyService.Api.Commands.Dtos;
using PolicyService.Api.Events;
using Xunit;

namespace PaymentService.Tests.Persistence;

public class MartenPersistenceTests : IClassFixture<MartenPaymentsFixture>
{
    private readonly MartenPaymentsFixture fixture;

    public MartenPersistenceTests(MartenPaymentsFixture fixture) => this.fixture = fixture;

    private static string NewNumber() => "LAB7-" + Guid.NewGuid().ToString("N");

    [Fact]
    public async Task FreshDocumentStoreRestoresProtectedPropertiesEntryTypesAndReferences()
    {
        var number = NewNumber();
        var now = DateTimeOffset.UtcNow;
        var account = new PolicyAccount(number, "BANK-7", "Kien", "Truong");
        account.ExpectedPayment(100.55m, now.AddDays(-2));
        account.InPayment(125.80m, now.AddDays(-1));
        account.OutPayment(5.25m, now);
        account.ExpectedPayment(200m, now.AddDays(1));

        using (var services = fixture.CreateServices())
        using (var scope = services.CreateScope())
        {
            var data = scope.ServiceProvider.GetRequiredService<IDataStore>();
            data.PolicyAccounts.Add(account);
            await data.CommitChanges();
        }

        // A new store/session must reconstruct the document without any in-memory state.
        using var restarted = fixture.CreateServices();
        using var readScope = restarted.CreateScope();
        var readData = readScope.ServiceProvider.GetRequiredService<IDataStore>();
        var restored = await readData.PolicyAccounts.FindByNumber(number);
        Assert.NotNull(restored);
        Assert.Equal(account.Id, restored.Id);
        Assert.Equal("BANK-7", restored.PolicyAccountNumber);
        Assert.Equal("Kien", restored.Owner.FirstName);
        Assert.Equal("Truong", restored.Owner.LastName);
        Assert.Equal(PolicyAccountStatus.Active, restored.Status);
        Assert.Equal(4, restored.Entries.Count);
        Assert.Equal(2, restored.Entries.OfType<ExpectedPayment>().Count());
        Assert.Single(restored.Entries.OfType<InPayment>());
        Assert.Single(restored.Entries.OfType<OutPayment>());
        Assert.All(restored.Entries, entry => Assert.Same(restored, entry.PolicyAccount));
        Assert.Equal(20m, restored.BalanceAt(now));
        Assert.Equal(-180m, restored.BalanceAt(now.AddDays(2)));
    }

    [Fact]
    public async Task DuplicatePolicyNumberRollsBackTheWholeTransaction()
    {
        using var services = fixture.CreateServices();
        var existingNumber = NewNumber();
        var otherNumber = NewNumber();
        using (var scope = services.CreateScope())
        {
            var data = scope.ServiceProvider.GetRequiredService<IDataStore>();
            data.PolicyAccounts.Add(new PolicyAccount(existingNumber, "ORIGINAL", "A", "B"));
            await data.CommitChanges();
        }

        using (var scope = services.CreateScope())
        {
            var data = scope.ServiceProvider.GetRequiredService<IDataStore>();
            data.PolicyAccounts.Add(new PolicyAccount(otherNumber, "OTHER", "C", "D"));
            data.PolicyAccounts.Add(new PolicyAccount(existingNumber, "DUPLICATE", "E", "F"));
            await Assert.ThrowsAnyAsync<Exception>(() => data.CommitChanges());
        }

        using var readScope = services.CreateScope();
        var readData = readScope.ServiceProvider.GetRequiredService<IDataStore>();
        Assert.False(await readData.PolicyAccounts.ExistsWithPolicyNumber(otherNumber));
        Assert.Equal("ORIGINAL", (await readData.PolicyAccounts.FindByNumber(existingNumber)).PolicyAccountNumber);
    }

    [Fact]
    public async Task InsertAndUpdateAreVisibleOnlyAfterCommit()
    {
        using var services = fixture.CreateServices();
        var discardedNumber = NewNumber();
        var number = NewNumber();
        using (var scope = services.CreateScope())
        {
            scope.ServiceProvider.GetRequiredService<IDataStore>().PolicyAccounts
                .Add(new PolicyAccount(discardedNumber, "DISCARDED", "A", "B"));
        }
        using (var scope = services.CreateScope())
        {
            var data = scope.ServiceProvider.GetRequiredService<IDataStore>();
            Assert.Null(await data.PolicyAccounts.FindByNumber(discardedNumber));
            data.PolicyAccounts.Add(new PolicyAccount(number, "BANK", "A", "B"));
            await data.CommitChanges();
        }
        using (var scope = services.CreateScope())
        {
            var data = scope.ServiceProvider.GetRequiredService<IDataStore>();
            var account = await data.PolicyAccounts.FindByNumber(number);
            account.InPayment(99.99m, DateTimeOffset.UtcNow.AddMinutes(-1));
            data.PolicyAccounts.Update(account);
            // Disposing without CommitChanges must discard the pending update.
        }
        using (var scope = services.CreateScope())
        {
            var data = scope.ServiceProvider.GetRequiredService<IDataStore>();
            var account = await data.PolicyAccounts.FindByNumber(number);
            Assert.Empty(account.Entries);
            account.InPayment(12.34m, DateTimeOffset.UtcNow.AddMinutes(-1));
            data.PolicyAccounts.Update(account);
            await data.CommitChanges();
        }
        using var readScope = services.CreateScope();
        var readData = readScope.ServiceProvider.GetRequiredService<IDataStore>();
        var result = await new GetAccountBalanceHandler(readData)
            .Handle(new GetAccountBalanceQuery { PolicyNumber = number }, CancellationToken.None);
        Assert.Equal(number, result.Balance.PolicyNumber);
        Assert.Equal(12.34m, result.Balance.Balance);
    }

    [Fact]
    public async Task PolicyEventsCreateOneAccountAndPersistTerminationAndRefund()
    {
        using var services = fixture.CreateServices();
        var number = NewNumber();
        var created = new PolicyCreated
        {
            PolicyNumber = number,
            PolicyHolder = new PersonDto { FirstName = "Kien", LastName = "Truong" }
        };
        for (var delivery = 0; delivery < 2; delivery++)
        {
            using var scope = services.CreateScope();
            await new PolicyCreatedHandler(scope.ServiceProvider.GetRequiredService<IDataStore>(),
                    new PolicyAccountNumberGenerator())
                .Handle(created, CancellationToken.None);
        }
        using (var session = services.GetRequiredService<IDocumentStore>().QuerySession())
        {
            Assert.Equal(1, await session.Query<PolicyAccount>().CountAsync(a => a.PolicyNumber == number));
        }
        var terminated = new PolicyTerminated
        {
            PolicyNumber = number,
            PolicyTo = DateTime.UtcNow.AddMinutes(-1),
            AmountToReturn = 7.25m
        };
        for (var delivery = 0; delivery < 2; delivery++)
        {
            using var scope = services.CreateScope();
            await new PolicyTerminatedHandler(scope.ServiceProvider.GetRequiredService<IDataStore>())
                .Handle(terminated, CancellationToken.None);
        }
        using var readScope = services.CreateScope();
        var account = await readScope.ServiceProvider.GetRequiredService<IDataStore>()
            .PolicyAccounts.FindByNumber(number);
        Assert.Equal(PolicyAccountStatus.Terminated, account.Status);
        Assert.Single(account.Entries.OfType<OutPayment>());
        Assert.Equal(-7.25m, account.BalanceAt(DateTimeOffset.UtcNow));
    }

    [Fact]
    public async Task DemoSeedingIsIdempotentAcrossFreshScopes()
    {
        using var services = fixture.CreateServices();
        for (var startup = 0; startup < 2; startup++)
        {
            using var scope = services.CreateScope();
            await new DataLoader(scope.ServiceProvider.GetRequiredService<IDataStore>()).Seed();
        }
        using var session = services.GetRequiredService<IDocumentStore>().QuerySession();
        foreach (var number in new[] { "POLICY_1", "POLICY_2", "POLICY_3" })
            Assert.Equal(1, await session.Query<PolicyAccount>().CountAsync(a => a.PolicyNumber == number));
    }
}
