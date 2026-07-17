using PactNet;
using PactNet.Infrastructure.Outputters;
using Xunit;
using Xunit.Abstractions;

namespace MySubscriptionService.ContractTests;

public class SubscriptionConsumerTests
{
    private readonly ITestOutputHelper _output;

    public SubscriptionConsumerTests(ITestOutputHelper output)
    {
        _output = output;
    }

    [Fact]
    public async Task CreateSubscription_Should_Generate_Valid_Contract()
    {
        var pact = Pact.V3("subscription-api-consumer", "subscription-api-provider", new PactConfig
        {
            PactDir = "../../../pact",
            Outputters = new[] { new XUnitOutputter(_output) }
        });

        pact.UponReceiving("a request to create a subscription")
            .Given("the service is healthy")
            .WithRequest(HttpMethod.Post, "/api/subscriptions")
            .WithHeader("Content-Type", "application/json")
            .WithJsonBody(new
            {
                customerName = "Pact Test User",
                email = "pact@test.com",
                plan = "Premium",
                amount = 99.99m
            })
            .WillRespond()
            .WithStatus(System.Net.HttpStatusCode.Created)
            .WithHeader("Content-Type", "application/json")
            .WithJsonBody(new
            {
                id = Guid.Empty,
                customerName = "Pact Test User",
                email = "pact@test.com",
                plan = "Premium",
                amount = 99.99m,
                createdAt = string.Empty,
                isActive = true
            });

        await pact.VerifyAsync();
    }
}

public class XUnitOutputter : IOutputter
{
    private readonly ITestOutputHelper _output;

    public XUnitOutputter(ITestOutputHelper output) => _output = output;

    public void Write(string message) => _output.WriteLine(message);
}