using Api.Middleware;
using Api.Repositories;
using Api.Services;
using Api.Settings;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace Api.UnitTests;

public class ApiTests
{
    [Fact]
    public async Task BookService_returns_books()
    {
        var repository = new InMemoryBookRepository();
        var service = new BookService(repository);

        var books = await service.GetBooksAsync();

        Assert.NotEmpty(books);
    }

    [Fact]
    public async Task ApiKeyMiddleware_blocks_missing_key()
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Request.Path = "/api/books";

        var middleware = new ApiKeyAuthMiddleware(
            (context) => Task.CompletedTask,
            Options.Create(new ApiKeySettings { Key = "expected-key" }),
            NullLogger<ApiKeyAuthMiddleware>.Instance);

        await middleware.InvokeAsync(httpContext);

        Assert.Equal(401, httpContext.Response.StatusCode);
    }

    [Fact]
    public async Task ApiKeyMiddleware_allows_health_endpoint()
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Request.Path = "/health";
        var wasCalled = false;

        var middleware = new ApiKeyAuthMiddleware(
            (context) => { wasCalled = true; return Task.CompletedTask; },
            Options.Create(new ApiKeySettings { Key = "expected-key" }),
            NullLogger<ApiKeyAuthMiddleware>.Instance);

        await middleware.InvokeAsync(httpContext);

        Assert.Equal(200, httpContext.Response.StatusCode);
        Assert.True(wasCalled);
    }
}
