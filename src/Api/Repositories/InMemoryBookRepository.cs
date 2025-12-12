using Api.Models;

namespace Api.Repositories;

public class InMemoryBookRepository : IBookRepository
{
    private static readonly IReadOnlyCollection<Book> Books = new List<Book>
    {
        new("1", "Clean Code", "Robert C. Martin", 34.99m),
        new("2", "The Pragmatic Programmer", "Andrew Hunt", 39.99m),
        new("3", "Design Patterns", "Erich Gamma", 44.99m)
    };

    public Task<IReadOnlyCollection<Book>> GetBooksAsync(CancellationToken cancellationToken = default)
    {
        return Task.FromResult(Books);
    }
}

