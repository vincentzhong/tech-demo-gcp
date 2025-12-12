using Api.Filters;
using Api.Repositories;
using Api.Services;
using Api.Settings;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
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
    public async Task ApiKeyFilter_blocks_missing_key()
    {
        var httpContext = new DefaultHttpContext();
        var actionContext = new ActionContext(
            httpContext,
            new RouteData(),
            new ControllerActionDescriptor { ActionName = "Get", ControllerName = "Books" });

        var filter = new ApiKeyAuthFilter(
            Options.Create(new ApiKeySettings { Key = "expected-key" }),
            NullLogger<ApiKeyAuthFilter>.Instance);

        var actionExecutingContext = new ActionExecutingContext(
            actionContext,
            new List<IFilterMetadata>(),
            new Dictionary<string, object?>(),
            controller: new object());

        var executed = new ActionExecutedContext(actionContext, new List<IFilterMetadata>(), controller: new object());
        ActionExecutionDelegate next = () => Task.FromResult(executed);

        await filter.OnActionExecutionAsync(actionExecutingContext, next);

        Assert.IsType<UnauthorizedResult>(actionExecutingContext.Result);
    }
}
