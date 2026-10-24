import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { movementsApi } from '../api/movements';
import Alert from '../components/Alert';
import EmptyState from '../components/EmptyState';
import Pagination from '../components/Pagination';
import Spinner from '../components/Spinner';
import { formatDateTime, formatNumber } from '../utils/format';

const PAGE_SIZE = 20;

export default function MovementsPage() {
  const [data, setData] = useState({ items: [], totalItems: 0, totalPages: 0 });
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadMovements = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      setData(await movementsApi.listAll({ page, pageSize: PAGE_SIZE }));
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [page]);

  useEffect(() => {
    loadMovements();
  }, [loadMovements]);

  return (
    <div className="stack-lg">
      <header className="page-header">
        <div>
          <p className="eyebrow">Audit trail</p>
          <h1>Riwayat stok</h1>
          <p className="muted">Seluruh transaksi stok masuk dan keluar milik akun ini.</p>
        </div>
        <Link to="/products" className="btn btn-secondary">Ke daftar produk</Link>
      </header>

      {error ? (
        <Alert type="error" onClose={() => setError('')}>
          {error} <button type="button" className="link-button" onClick={loadMovements}>Coba lagi</button>
        </Alert>
      ) : null}

      {loading ? (
        <Spinner label="Memuat riwayat stok..." />
      ) : data.items.length === 0 ? (
        <EmptyState
          title="Belum ada riwayat"
          description="Transaksi stok masuk/keluar akan muncul di sini setelah dicatat dari detail produk."
          action={<Link to="/products" className="btn btn-primary">Pilih produk</Link>}
        />
      ) : (
        <section className="card card-flush">
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Waktu</th>
                  <th>Produk</th>
                  <th>SKU</th>
                  <th>Tipe</th>
                  <th className="text-right">Qty</th>
                  <th className="text-right">Sebelum</th>
                  <th className="text-right">Sesudah</th>
                  <th>Catatan</th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((movement) => (
                  <tr key={movement.id}>
                    <td className="muted">{formatDateTime(movement.createdAt)}</td>
                    <td>
                      <Link className="table-link" to={`/products/${movement.productId}`}>
                        {movement.productName}
                      </Link>
                    </td>
                    <td className="mono">{movement.productSku}</td>
                    <td>
                      <span className={`badge ${movement.type === 'IN' ? 'badge-success' : 'badge-danger'}`}>
                        {movement.type}
                      </span>
                    </td>
                    <td className="text-right">{formatNumber(movement.quantity)}</td>
                    <td className="text-right">{formatNumber(movement.stockBefore)}</td>
                    <td className="text-right">{formatNumber(movement.stockAfter)}</td>
                    <td className="muted">{movement.note || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Pagination
            page={page}
            totalPages={data.totalPages}
            totalItems={data.totalItems}
            pageSize={PAGE_SIZE}
            onPageChange={setPage}
          />
        </section>
      )}
    </div>
  );
}
