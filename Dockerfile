# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY TechDemo.Gcp.sln .
COPY src/Api/Api.csproj src/Api/
COPY tests/Api.UnitTests/Api.UnitTests.csproj tests/Api.UnitTests/
RUN dotnet restore

COPY . .
RUN dotnet publish src/Api/Api.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://0.0.0.0:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "Api.dll"]

