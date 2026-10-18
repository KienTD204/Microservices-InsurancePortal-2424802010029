using GlobalExceptionHandler.WebApi;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Newtonsoft.Json;
using PricingService.Configuration;
using PricingService.DataAccess.Marten;
using PricingService.Infrastructure;
using PricingService.Init;
using Steeltoe.Discovery.Client;

namespace PricingService;

public class Startup
{
    public Startup(IConfiguration configuration)
    {
        Configuration = configuration;
    }

    public IConfiguration Configuration { get; }

    // This method gets called by the runtime. Use this method to add services to the container.
    public void ConfigureServices(IServiceCollection services)
    {
        services.AddDiscoveryClient(Configuration);
        services.AddControllers()
            .AddNewtonsoftJson(opt => { opt.SerializerSettings.TypeNameHandling = TypeNameHandling.Auto; });

        services.AddMarten(Configuration.GetConnectionString("DefaultConnection"));
        services.AddPricingDemoInitializer();
        services.AddMediatR(options => options.RegisterServicesFromAssemblyContaining<Program>());
        services.AddLoggingBehavior();
        services.AddSwaggerGen();
    }

    // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
    public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
    {
        app.UseRouting();
        app.UseGlobalExceptionHandler(cfg => cfg.MapExceptions());

        if (env.IsDevelopment())
        {
            app.UseSwagger();
            app.UseSwaggerUI();
        }

        // Startup.Configure is synchronous; finish seeding before accepting requests.
        app.UseInitializer().GetAwaiter().GetResult();
        app.UseEndpoints(endpoints =>
        {
            endpoints.MapControllers();
            endpoints.MapGet("/health", context => context.Response.WriteAsJsonAsync(new { status = "UP" }));
            endpoints.MapGet("/info", context => context.Response.WriteAsJsonAsync(new
            {
                application = "PricingService", assignment = "Lab 5 - Eureka Discovery"
            }));
        });

        // Kept to match the assignment. Steeltoe >= 3.1 also starts discovery via IHostedService.
        app.UseDiscoveryClient();
    }
}
