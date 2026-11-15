namespace BlazorWasmClient.Components.Auth;

public class AuthResponse
{
    public string Token { get; set; }
    public string UserName { get; set; }
    public string[] Roles { get; set; }
    public string Avatar { get; set; }
    public string UserType { get; set; }
    // AuthService returns this value as "expiryTimeStamp"; without the mapping it stays DateTime.MinValue,
    // the session is treated as expired and every gateway call is sent without a token (HTTP 401).
    [System.Text.Json.Serialization.JsonPropertyName("expiryTimeStamp")]
    public DateTime ExpiresIn { get; set; }
}
