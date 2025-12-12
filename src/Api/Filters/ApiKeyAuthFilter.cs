using Api.Settings;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.Options;

namespace Api.Filters;

public class ApiKeyAuthFilter : IAsyncActionFilter
{
    private readonly ApiKeySettings _settings;
    private readonly ILogger<ApiKeyAuthFilter> _logger;

    public ApiKeyAuthFilter(IOptions<ApiKeySettings> options, ILogger<ApiKeyAuthFilter> logger)
    {
        _settings = options.Value;
        _logger = logger;
    }

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var configuredKey = _settings.Key;
        if (string.IsNullOrWhiteSpace(configuredKey))
        {
            _logger.LogWarning("API key not configured");
            context.Result = new UnauthorizedObjectResult("API key not configured");
            return;
        }

        if (!context.HttpContext.Request.Headers.TryGetValue(ApiKeySettings.HeaderName, out var providedKey) ||
            providedKey != configuredKey)
        {
            _logger.LogWarning("Unauthorized request: missing or invalid API key");
            context.Result = new UnauthorizedResult();
            return;
        }

        await next();
    }
}

