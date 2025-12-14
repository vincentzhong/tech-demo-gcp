using Api.Middleware;
using Api.Repositories;
using Api.Services;
using Api.Settings;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// Only add Swagger in development
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();
}

builder.Services.Configure<ApiKeySettings>(builder.Configuration.GetSection(ApiKeySettings.SectionName));

builder.Services.AddSingleton<IBookRepository, InMemoryBookRepository>();
builder.Services.AddScoped<IBookService, BookService>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Don't use HTTPS redirection in Cloud Run - it handles TLS termination
// app.UseHttpsRedirection();

// API key authentication middleware (applies globally except /health)
app.UseMiddleware<ApiKeyAuthMiddleware>();

app.MapControllers();
app.MapGet("/", () => Results.Ok("OK"));

app.Run();
