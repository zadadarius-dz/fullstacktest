export default function Pagination({ page, totalPages, totalItems, pageSize, onPageChange }) {
  if (!totalItems) return null;

  const start = (page - 1) * pageSize + 1;
  const end = Math.min(page * pageSize, totalItems);
  const pages = [];
  const first = Math.max(1, page - 2);
  const last = Math.min(totalPages, first + 4);

  for (let index = first; index <= last; index += 1) {
    pages.push(index);
  }

  return (
    <div className="pagination">
      <span className="pagination-info">
        Menampilkan {start}–{end} dari {totalItems} data
      </span>
      <div className="pagination-controls">
        <button
          type="button"
          className="btn btn-secondary btn-sm"
          onClick={() => onPageChange(page - 1)}
          disabled={page <= 1}
        >
          Sebelumnya
        </button>
        {pages.map((number) => (
          <button
            type="button"
            key={number}
            className={`page-button ${number === page ? 'is-active' : ''}`}
            onClick={() => onPageChange(number)}
            aria-current={number === page ? 'page' : undefined}
          >
            {number}
          </button>
        ))}
        <button
          type="button"
          className="btn btn-secondary btn-sm"
          onClick={() => onPageChange(page + 1)}
          disabled={page >= totalPages}
        >
          Berikutnya
        </button>
      </div>
    </div>
  );
}
