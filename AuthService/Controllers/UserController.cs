using AuthService.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AuthService.Controllers;

[Authorize]
[Route("api/[controller]")]
[ApiController]
public class UserController : ControllerBase
{
    private readonly Domain.AuthService authService;

    public UserController(Domain.AuthService authService)
    {
        this.authService = authService;
    }

    [AllowAnonymous]
    [HttpPost]
    public IActionResult Post([FromBody] AuthRequest user)
    {
        var authResult = authService.Authenticate(user.Login, user.Password);

        if (authResult == null)
            return BadRequest(new { message = "Username or password incorrect" });

        return Ok(new
        {
            Token = authResult.Token,
            UserName = authResult.Login,
            Roles = authResult.Roles,
            Avatar = authResult.Avatar,
            UserType = authResult.UserType,
            ExpiryTimeStamp = authResult.ExpiryTimeStamp
        });
    }

    [HttpGet]
    public IActionResult Get()
    {
        var agent = authService.AgentFromLogin(HttpContext.User.Identity.Name);
        if (agent == null) return Unauthorized();

        return Ok(new { agent.Login, agent.Avatar, agent.AvailableProducts });
    }
}
