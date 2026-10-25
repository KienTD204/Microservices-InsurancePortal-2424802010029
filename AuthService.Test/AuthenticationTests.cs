using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using AuthService.DataAccess;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace AuthService.Test;

public class AuthenticationTests
{
    private const string Secret = "LAB6_TEST_ONLY_HMAC_KEY_WITH_AT_LEAST_32_BYTES";
    private readonly global::AuthService.Domain.AuthService service = new(
        new InsuranceAgentsInMemoryDb(),
        Options.Create(new AppSettings { Secret = Secret }));

    [Theory]
    [InlineData("jimmy.solid", "secret")]
    [InlineData("danny.solid", "secret")]
    [InlineData("admin", "admin")]
    public void Valid_credentials_issue_a_signed_JWT_with_agent_identity(string login, string password)
    {
        var result = service.Authenticate(login, password);
        Assert.NotNull(result);
        var principal = new JwtSecurityTokenHandler().ValidateToken(result.Token, new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Secret)),
            ValidateIssuer = false,
            ValidateAudience = false,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero
        }, out var validatedToken);

        Assert.Equal(login, principal.Identity!.Name);
        Assert.True(principal.IsInRole("SALESMAN"));
        Assert.True(principal.IsInRole("USER"));
        Assert.Equal("SALESMAN", principal.FindFirst("userType")!.Value);
        Assert.NotNull(principal.FindFirst("avatar"));
        Assert.Equal(SecurityAlgorithms.HmacSha256, ((JwtSecurityToken)validatedToken).Header.Alg);
        Assert.InRange(validatedToken.ValidTo, DateTime.UtcNow.AddDays(6), DateTime.UtcNow.AddDays(7));
    }

    [Theory]
    [InlineData("unknown.agent", "secret")]
    [InlineData("jimmy.solid", "wrong-password")]
    [InlineData("", "secret")]
    [InlineData(null, "secret")]
    [InlineData("jimmy.solid", null)]
    public void Invalid_credentials_are_rejected_without_an_exception(string? login, string? password)
    {
        Assert.Null(service.Authenticate(login!, password!));
    }
}
