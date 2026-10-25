using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using JsonSerializer = System.Text.Json.JsonSerializer;
using EasyNetQ;
using EasyNetQ.Topology;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.SignalR.Client;
using PolicyService.Api.Commands.Dtos;
using PolicyService.Api.Events;

var output = args.Length > 0 ? args[0] : "submission/lab6/evidence/runtime-verification.json";
var checks = new List<object>();
using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
var runId = Guid.NewGuid().ToString("N");
var eurekaUrl = Environment.GetEnvironmentVariable("LAB6_EUREKA_URL") ?? "http://localhost:8761";
var rabbitConnection = Environment.GetEnvironmentVariable("LAB6_RABBITMQ_CONNECTION") ?? "host=localhost;port=5672;username=guest;password=guest";

void Check(string name, bool condition, object? detail = null)
{
    checks.Add(new { name, passed = condition, detail });
    Console.WriteLine($"{(condition ? "PASS" : "FAIL")}: {name}");
    if (!condition) throw new InvalidOperationException(name);
}

async Task<JsonElement> Post(string url, object body, string? token = null)
{
    using var request = new HttpRequestMessage(HttpMethod.Post, url) { Content = JsonContent.Create(body) };
    if (token != null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
    using var response = await http.SendAsync(request);
    response.EnsureSuccessStatusCode();
    return (await response.Content.ReadFromJsonAsync<JsonElement>()).Clone();
}

async Task<string> Login(string login)
{
    var result = await Post("http://localhost:6060/api/User", new { login, password = "secret" });
    var token = result.GetProperty("token").GetString()!;
    Check($"AuthService issues JWT for {login}", token.Split('.').Length == 3);
    return token;
}

HubConnection Connect(string token) => new HubConnectionBuilder()
    .WithUrl("http://localhost:4099/agentsChat", options =>
    {
        options.AccessTokenProvider = () => Task.FromResult<string?>(token);
        options.Transports = HttpTransportType.WebSockets;
    }).Build();

try
{
    foreach (var url in new[] { "http://localhost:6060/api/User", "http://localhost:8099/Products/TRI", "http://localhost:8099/api/Dashboard/total-sales" })
    {
        using var request = new HttpRequestMessage(url.EndsWith("total-sales") ? HttpMethod.Post : HttpMethod.Get, url);
        if (request.Method == HttpMethod.Post) request.Content = JsonContent.Create(new { });
        using var response = await http.SendAsync(request);
        Check($"Anonymous request is blocked: {new Uri(url).AbsolutePath}", response.StatusCode == HttpStatusCode.Unauthorized, (int)response.StatusCode);
    }
    using (var bad = await http.PostAsJsonAsync("http://localhost:6060/api/User", new { login = "lab6.missing", password = "wrong" }))
        Check("Unknown account returns HTTP 400", bad.StatusCode == HttpStatusCode.BadRequest, (int)bad.StatusCode);
    using (var bad = await http.PostAsJsonAsync("http://localhost:6060/api/User", new { }))
        Check("Missing credentials return HTTP 400", bad.StatusCode == HttpStatusCode.BadRequest, (int)bad.StatusCode);

    var jimmy = await Login("jimmy.solid");
    var danny = await Login("danny.solid");
    using (var request = new HttpRequestMessage(HttpMethod.Get, "http://localhost:6060/api/User"))
    {
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", jimmy);
        using var response = await http.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var profile = await response.Content.ReadFromJsonAsync<JsonElement>();
        Check("Authenticated profile does not expose a password", profile.GetProperty("login").GetString() == "jimmy.solid" && !profile.TryGetProperty("password", out _));
    }

    foreach (var path in new[] { "/Products/TRI", "/api/Products/TRI", "/Products", "/api/Products" })
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, "http://localhost:8099" + path);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", jimmy);
        using var response = await http.SendAsync(request);
        var body = await response.Content.ReadAsStringAsync();
        Check($"Eureka/Ocelot forwards {path}", response.IsSuccessStatusCode && body.Contains("TRI"), (int)response.StatusCode);
    }

    using (var response = await http.PostAsync("http://localhost:4099/agentsChat/negotiate?negotiateVersion=1", null))
        Check("SignalR rejects anonymous negotiation", response.StatusCode == HttpStatusCode.Unauthorized, (int)response.StatusCode);

    await using var clientA = Connect(jimmy);
    await using var clientB = Connect(danny);
    var receivedA = new TaskCompletionSource<(string User, string Text)>(TaskCreationOptions.RunContinuationsAsynchronously);
    var receivedB = new TaskCompletionSource<(string User, string Text)>(TaskCreationOptions.RunContinuationsAsynchronously);
    var notification = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
    var eventNotice = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
    var chatText = "lab6-chat-" + runId;
    var noticeText = "lab6-notification-" + runId;
    var agent = "lab6.verifier." + runId;
    clientA.On<string, string, string>("ReceiveMessage", (user, avatar, text) => { if (text == chatText) receivedA.TrySetResult((user, text)); });
    clientB.On<string, string, string>("ReceiveMessage", (user, avatar, text) => { if (text == chatText) receivedB.TrySetResult((user, text)); });
    clientB.On<string>("ReceiveNotification", text =>
    {
        if (text == noticeText) notification.TrySetResult(text);
        if (text.Contains(agent)) eventNotice.TrySetResult(text);
    });
    await clientA.StartAsync();
    await clientB.StartAsync();
    await clientA.InvokeAsync("SendMessage", chatText);
    var a = await receivedA.Task.WaitAsync(TimeSpan.FromSeconds(15));
    var b = await receivedB.Task.WaitAsync(TimeSpan.FromSeconds(15));
    Check("Two authenticated SignalR clients receive the chat message", a.User == "jimmy.solid" && b.User == "jimmy.solid");
    using (var request = new HttpRequestMessage(HttpMethod.Post, "http://localhost:4099/api/Notification") { Content = JsonContent.Create(new { message = noticeText }) })
    {
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", jimmy);
        using var response = await http.SendAsync(request);
        response.EnsureSuccessStatusCode();
    }
    Check("Notification command reaches SignalR clients", await notification.Task.WaitAsync(TimeSpan.FromSeconds(15)) == noticeText);

    var from = DateTime.Today;
    var policy = new PolicyCreated
    {
        PolicyNumber = "LAB6-" + runId,
        ProductCode = "TRI",
        PolicyFrom = from,
        PolicyTo = from.AddDays(7),
        PolicyHolder = new PersonDto { FirstName = "Lab6", LastName = "Verifier" },
        TotalPremium = 123.45m,
        AgentLogin = agent
    };
    using (var bus = RabbitHutch.CreateBus(rabbitConnection))
    {
        var exchange = await bus.Advanced.ExchangeDeclareAsync("lab-dotnet-micro", ExchangeType.Topic);
        await bus.Advanced.PublishAsync(exchange, "policycreated", false, new Message<PolicyCreated>(policy));
    }
    Check("RabbitMQ PolicyCreated produces a live chat notification", (await eventNotice.Task.WaitAsync(TimeSpan.FromSeconds(30))).Contains(agent));
    JsonElement sales = default;
    var indexed = false;
    for (var attempt = 0; attempt < 30; attempt++)
    {
        sales = await Post("http://localhost:8099/api/Dashboard/agents-sales", new { agentLogin = agent }, jimmy);
        if (sales.GetProperty("perAgentTotal").TryGetProperty(agent, out var total) && total.GetProperty("premiumAmount").GetDecimal() == 123.45m && total.GetProperty("policiesCount").GetInt64() == 1)
        { indexed = true; break; }
        await Task.Delay(1000);
    }
    Check("RabbitMQ PolicyCreated is indexed once in Dashboard via Elasticsearch", indexed, new { policy.PolicyNumber, agent, premium = 123.45m });
    foreach (var endpoint in new[] { "total-sales", "sales-trends" })
    {
        var report = await Post("http://localhost:8099/api/Dashboard/" + endpoint,
            new { productCode = "TRI", salesDateFrom = from.AddDays(-1), salesDateTo = from.AddDays(1), unit = 0 }, jimmy);
        Check("Dashboard responds through Gateway: " + endpoint, report.ValueKind == JsonValueKind.Object);
    }
    using var registryRequest = new HttpRequestMessage(HttpMethod.Get, eurekaUrl + "/eureka/apps");
    registryRequest.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
    using var registryResponse = await http.SendAsync(registryRequest);
    registryResponse.EnsureSuccessStatusCode();
    var registry = await registryResponse.Content.ReadAsStringAsync();
    Check("ProductService and DashboardService are registered in Eureka", registry.Contains("PRODUCTSERVICE") && registry.Contains("DASHBOARDSERVICE"));

    Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output))!);
    await File.WriteAllTextAsync(output, JsonSerializer.Serialize(new
    {
        checkedAt = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)), result = "PASS", checks,
        syntheticPolicy = policy.PolicyNumber,
        note = "One uniquely identified verification policy is intentionally retained in the local lab index. JWT values are never written to this report."
    }, new JsonSerializerOptions { WriteIndented = true }));
    Console.WriteLine($"PASS: {checks.Count} runtime checks; report saved to {output}");
    return 0;
}
catch (Exception exception)
{
    Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output))!);
    await File.WriteAllTextAsync(output, JsonSerializer.Serialize(new { result = "FAIL", checks, error = exception.Message }, new JsonSerializerOptions { WriteIndented = true }));
    Console.Error.WriteLine(exception.Message);
    return 1;
}
