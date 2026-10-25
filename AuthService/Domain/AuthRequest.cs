using System.ComponentModel.DataAnnotations;

namespace AuthService.Domain;

public class AuthRequest
{
    [Required] public string Login { get; set; }
    [Required] public string Password { get; set; }
}
