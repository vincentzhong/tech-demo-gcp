using Api.Models;

namespace Api.Repositories;

public interface IBookRepository
{
    Task<IReadOnlyCollection<Book>> GetBooksAsync(CancellationToken cancellationToken = default);
}

