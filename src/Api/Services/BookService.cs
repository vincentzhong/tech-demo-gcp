using Api.Models;
using Api.Repositories;

namespace Api.Services;

public class BookService : IBookService
{
    private readonly IBookRepository _bookRepository;

    public BookService(IBookRepository bookRepository)
    {
        _bookRepository = bookRepository;
    }

    public Task<IReadOnlyCollection<Book>> GetBooksAsync(CancellationToken cancellationToken = default)
    {
        return _bookRepository.GetBooksAsync(cancellationToken);
    }
}

