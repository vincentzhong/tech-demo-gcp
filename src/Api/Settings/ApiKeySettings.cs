namespace Api.Settings;

public class ApiKeySettings
{
    public const string SectionName = "ApiKeySettings";
    public const string HeaderName = "X-API-KEY";

    public string? Key { get; set; }
}

