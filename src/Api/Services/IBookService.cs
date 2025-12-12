using Api.Models;

namespace Api.Services;

public interface IBookService
{
    Task<IReadOnlyCollection<Book>> GetBooksAsync(CancellationToken cancellationToken = default);
}

