import { useCallback, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { movementsApi } from '../api/movements';
import { productsApi } from '../api/products';
import Alert from '../components/Alert';
import EmptyState from '../components/EmptyState';
import Pagination from '../components/Pagination';
import Spinner from '../components/Spinner';
import { formatCurrency, formatDateTime, formatNumber } from '../utils/format';
import { validateMovement } from '../utils/validation';

const HISTORY_PAGE_SIZE = 10;

export default function ProductDetailPage() {
  const { id } = useParams();
  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const [history, setHistory] = useState({ items: [], totalItems: 0, totalPages: 0, page: 1 });
  const [historyPage, setHistoryPage] = useState(1);
  const [historyLoading, setHistoryLoading] = useState(true);

  const [movementForm, setMovementForm] = useState({ type: 'IN', quantity: '', note: '' });
  const [movementErrors, setMovementErrors] = useState({});
  const [movementError, setMovementError] = useState('');
  const [movementNotice, setMovementNotice] = useState('');
  const [savingMovement, setSavingMovement] = useState(false);

  const loadProduct = useCallback(async () => {
    setError('');
    try {
      setProduct(await productsApi.get(id));
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [id]);

  const loadHistory = useCallback(async () => {
    setHistoryLoading(true);
    try {
      const data = await movementsApi.listForProduct(id, {
        page: historyPage,
        pageSize: HISTORY_PAGE_SIZE,
      });
      setHistory(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setHistoryLoading(false);
    }
  }, [id, historyPage]);

  useEffect(() => {
    loadProduct();
  }, [loadProduct]);

  useEffect(() => {
    loadHistory();
  }, [loadHistory]);

  const handleMovementChange = (event) => {
    const { name, value } = event.target;
    setMovementForm((current) => ({ ...current, [name]: value }));
    setMovementErrors((current) => ({ ...current, [name]: undefined }));
  };

  const handleMovementSubmit = async (event) => {
    event.preventDefault();
    setMovementError('');
    setMovementNotice('');

    const validationErrors = validateMovement(movementForm);
    if (Object.keys(validationErrors).length > 0) {
      setMovementErrors(validationErrors);
      return;
    }

    setSavingMovement(true);
    try {
      const result = await movementsApi.createForProduct(id, {
        type: movementForm.type,
        quantity: Number(movementForm.quantity),
        note: movementForm.note.trim() || null,
      });
      setMovementNotice(
        `Stok ${result.type === 'IN' ? 'masuk' : 'keluar'} ${result.quantity} berhasil dicatat. Stok sekarang ${result.stockAfter}.`,
      );
      setMovementForm({ type: movementForm.type, quantity: '', note: '' });
      await loadProduct();
      if (historyPage === 1) {
        await loadHistory();
      } else {
        // Mengubah historyPage memicu effect yang memuat halaman pertama.
        setHistoryPage(1);
      }
    } catch (err) {
      setMovementError(err.message);
    } finally {
      setSavingMovement(false);
    }
  };

  if (loading) {
    return <Spinner label="Memuat detail produk..." />;
  }

  if (error && !product) {
    return (
      <div className="stack-lg">
        <Alert type="error">{error}</Alert>
        <Link to="/products" className="btn btn-secondary">Kembali ke daftar produk</Link>
      </div>
    );
  }

  const isLow = product && product.stockQuantity <= product.minStock;

  return (
    <div className="stack-lg">
      <header className="page-header">
        <div>
          <p className="eyebrow">Detail produk</p>
          <h1>{product?.name}</h1>
          <p className="muted">
            <span className="mono">{product?.sku}</span> · {product?.categoryName}
          </p>
        </div>
        <div className="header-actions">
          <Link to="/products" className="btn btn-secondary">Kembali</Link>
          <Link to={`/products/${id}/edit`} className="btn btn-primary">Edit produk</Link>
        </div>
      </header>

      {error ? <Alert type="error" onClose={() => setError('')}>{error}</Alert> : null}

      <section className="detail-grid">
        <div className="card stack">
          <h2>Informasi produk</h2>
          <dl className="detail-list">
            <div>
              <dt>Harga</dt>
              <dd>{formatCurrency(product?.price)}</dd>
            </div>
            <div>
              <dt>Stok saat ini</dt>
              <dd>
                <span className={`badge ${isLow ? 'badge-warning' : 'badge-success'}`}>
                  {formatNumber(product?.stockQuantity)}
                </span>
              </dd>
            </div>
            <div>
              <dt>Stok minimum</dt>
              <dd>{formatNumber(product?.minStock)}</dd>
            </div>
            <div>
              <dt>Status</dt>
              <dd>{product?.isActive ? 'Aktif' : 'Nonaktif'}</dd>
            </div>
            <div className="detail-list-full">
              <dt>Deskripsi</dt>
              <dd>{product?.description || '—'}</dd>
            </div>
          </dl>
        </div>

        <div className="card stack">
          <h2>Catat pergerakan stok</h2>
          <p className="muted">Stok masuk menambah, stok keluar mengurangi. Stok tidak dapat menjadi negatif.</p>

          {movementNotice ? (
            <Alert type="success" onClose={() => setMovementNotice('')}>{movementNotice}</Alert>
          ) : null}
          {movementError ? (
            <Alert type="error" onClose={() => setMovementError('')}>{movementError}</Alert>
          ) : null}

          <form className="stack" onSubmit={handleMovementSubmit} noValidate>
            <div className="form-grid form-grid-2">
              <label className="field">
                <span>Tipe</span>
                <select
                  name="type"
                  value={movementForm.type}
                  onChange={handleMovementChange}
                  disabled={savingMovement}
                >
                  <option value="IN">IN — stok masuk</option>
                  <option value="OUT">OUT — stok keluar</option>
                </select>
              </label>

              <label className="field">
                <span>Quantity</span>
                <input
                  type="number"
                  name="quantity"
                  value={movementForm.quantity}
                  onChange={handleMovementChange}
                  min="1"
                  step="1"
                  placeholder="Contoh: 10"
                  className={movementErrors.quantity ? 'has-error' : ''}
                  disabled={savingMovement}
                />
                {movementErrors.quantity ? (
                  <small className="field-error">{movementErrors.quantity}</small>
                ) : null}
              </label>
            </div>

            <label className="field">
              <span>Catatan (opsional)</span>
              <input
                type="text"
                name="note"
                value={movementForm.note}
                onChange={handleMovementChange}
                maxLength={300}
                placeholder="Contoh: Pembelian dari pemasok"
                className={movementErrors.note ? 'has-error' : ''}
                disabled={savingMovement}
              />
              {movementErrors.note ? <small className="field-error">{movementErrors.note}</small> : null}
            </label>

            <button type="submit" className="btn btn-primary" disabled={savingMovement}>
              {savingMovement ? 'Menyimpan...' : 'Simpan transaksi'}
            </button>
          </form>
        </div>
      </section>

      <section className="card card-flush">
        <div className="card-header card-header-padded">
          <div>
            <h2>Riwayat stok</h2>
            <p className="muted">Riwayat bersifat permanen dan tidak dapat diubah.</p>
          </div>
        </div>

        {historyLoading ? (
          <div className="card-padded"><Spinner label="Memuat riwayat..." /></div>
        ) : history.items.length === 0 ? (
          <EmptyState
            title="Belum ada transaksi"
            description="Catat stok masuk atau keluar pertama melalui form di atas."
          />
        ) : (
          <>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Waktu</th>
                    <th>Tipe</th>
                    <th className="text-right">Qty</th>
                    <th className="text-right">Sebelum</th>
                    <th className="text-right">Sesudah</th>
                    <th>Catatan</th>
                  </tr>
                </thead>
                <tbody>
                  {history.items.map((movement) => (
                    <tr key={movement.id}>
                      <td className="muted">{formatDateTime(movement.createdAt)}</td>
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
              page={historyPage}
              totalPages={history.totalPages}
              totalItems={history.totalItems}
              pageSize={HISTORY_PAGE_SIZE}
              onPageChange={setHistoryPage}
            />
          </>
        )}
      </section>
    </div>
  );
}
