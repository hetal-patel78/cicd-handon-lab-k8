using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace MySubscriptionService.ComponentTests;

public class SubscriptionApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public SubscriptionApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task CreateAndGetSubscription_Should_Work_EndToEnd()
    {
        var createRequest = new
        {
            CustomerName = "Component Test User",
            Email = "comp@test.com",
            Plan = "Enterprise",
            Amount = 499.99m
        };

        var createResponse = await _client.PostAsJsonAsync("/api/subscriptions", createRequest);
        createResponse.StatusCode.Should().Be(System.Net.HttpStatusCode.Created);

        var created = await createResponse.Content.ReadFromJsonAsync<SubscriptionDto>();
        created.Should().NotBeNull();
        created!.CustomerName.Should().Be("Component Test User");

        var getResponse = await _client.GetAsync($"/api/subscriptions/{created.Id}");
        getResponse.StatusCode.Should().Be(System.Net.HttpStatusCode.OK);

        var fetched = await getResponse.Content.ReadFromJsonAsync<SubscriptionDto>();
        fetched.Should().NotBeNull();
        fetched!.Email.Should().Be("comp@test.com");
    }

    [Fact]
    public async Task Ping_Should_Return_Healthy()
    {
        var response = await _client.GetAsync("/ping");
        response.StatusCode.Should().Be(System.Net.HttpStatusCode.OK);
    }
}

public class SubscriptionDto
{
    public Guid Id { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Plan { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public DateTime CreatedAt { get; set; }
    public bool IsActive { get; set; }
}