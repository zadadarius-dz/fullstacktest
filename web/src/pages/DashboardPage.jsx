import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { dashboardApi } from '../api/dashboard';
import Alert from '../components/Alert';
import EmptyState from '../components/EmptyState';
import Spinner from '../components/Spinner';
import StatCard from '../components/StatCard';
import { formatNumber } from '../utils/format';

export default function DashboardPage() {
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadSummary = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      setSummary(await dashboardApi.summary());
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadSummary();
  }, [loadSummary]);

  return (
    <div className="stack-lg">
      <header className="page-header">
        <div>
          <p className="eyebrow">Ringkasan</p>
          <h1>Dashboard</h1>
          <p className="muted">Kondisi inventaris Anda saat ini.</p>
        </div>
        <div className="header-actions">
          <Link to="/products/new" className="btn btn-primary">+ Produk baru</Link>
          <Link to="/products" className="btn btn-secondary">Lihat produk</Link>
        </div>
      </header>

      {error ? (
        <Alert type="error" onClose={() => setError('')}>
          {error}{' '}
          <button type="button" className="link-button" onClick={loadSummary}>Coba lagi</button>
        </Alert>
      ) : null}

      {loading ? (
        <Spinner label="Memuat ringkasan..." />
      ) : summary ? (
        <>
          <section className="stat-grid" aria-label="Statistik inventaris">
            <StatCard
              label="Produk aktif"
              value={formatNumber(summary.activeProducts)}
              hint="Produk yang belum dihapus"
            />
            <StatCard
              label="Kategori"
              value={formatNumber(summary.categories)}
              hint="Kategori milik akun ini"
            />
            <StatCard
              label="Total unit stok"
              value={formatNumber(summary.totalStockUnits)}
              hint="Akumulasi seluruh produk aktif"
              tone="accent"
            />
            <StatCard
              label="Stok menipis"
              value={formatNumber(summary.lowStockProducts)}
              hint="Stok ≤ batas minimum"
              tone={summary.lowStockProducts > 0 ? 'warning' : 'default'}
            />
          </section>

          <section className="card">
            <div className="card-header">
              <div>
                <h2>Perlu restock</h2>
                <p className="muted">Produk dengan stok sama atau di bawah batas minimum.</p>
              </div>
              <Link to="/products?lowStock=true" className="btn btn-secondary btn-sm">
                Lihat semua
              </Link>
            </div>

            {summary.lowStockItems.length === 0 ? (
              <EmptyState
                title="Semua stok aman"
                description="Tidak ada produk yang berada di bawah batas minimum saat ini."
              />
            ) : (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>SKU</th>
                      <th>Produk</th>
                      <th className="text-right">Stok</th>
                      <th className="text-right">Minimum</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {summary.lowStockItems.map((item) => (
                      <tr key={item.id}>
                        <td className="mono">{item.sku}</td>
                        <td>{item.name}</td>
                        <td className="text-right">
                          <span className="badge badge-warning">{item.stockQuantity}</span>
                        </td>
                        <td className="text-right">{item.minStock}</td>
                        <td className="text-right">
                          <Link className="link-button" to={`/products/${item.id}`}>
                            Catat stok
                          </Link>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </>
      ) : null}
    </div>
  );
}
