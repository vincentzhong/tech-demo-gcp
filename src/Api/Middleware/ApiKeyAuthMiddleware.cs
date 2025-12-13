using Api.Settings;
using Microsoft.Extensions.Options;

namespace Api.Middleware;

public class ApiKeyAuthMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ApiKeySettings _settings;
    private readonly ILogger<ApiKeyAuthMiddleware> _logger;

    public ApiKeyAuthMiddleware(
        RequestDelegate next,
        IOptions<ApiKeySettings> options,
        ILogger<ApiKeyAuthMiddleware> logger)
    {
        _next = next;
        _settings = options.Value;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Skip auth for health endpoint
        if (context.Request.Path.StartsWithSegments("/health"))
        {
            await _next(context);
            return;
        }

        var configuredKey = _settings.Key;
        if (string.IsNullOrWhiteSpace(configuredKey))
        {
            _logger.LogWarning("API key not configured");
            context.Response.StatusCode = 401;
            await context.Response.WriteAsync("API key not configured");
            return;
        }

        if (!context.Request.Headers.TryGetValue(ApiKeySettings.HeaderName, out var providedKey) ||
            providedKey != configuredKey)
        {
            _logger.LogWarning("Unauthorized request: missing or invalid API key");
            context.Response.StatusCode = 401;
            await context.Response.WriteAsync("Unauthorized");
            return;
        }

        await _next(context);
    }
}

