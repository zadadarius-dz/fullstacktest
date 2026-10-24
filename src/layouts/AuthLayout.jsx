import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context/useAuth';
import Spinner from '../components/Spinner';

export default function AuthLayout() {
  const { isAuthenticated, loading } = useAuth();

  if (loading) {
    return (
      <div className="fullscreen-center">
        <Spinner label="Memuat StockMate..." />
      </div>
    );
  }

  if (isAuthenticated) {
    return <Navigate to="/dashboard" replace />;
  }

  return (
    <div className="auth-shell">
      <section className="auth-hero">
        <div className="auth-brand">
          <span className="brand-mark brand-mark-lg" aria-hidden="true">S</span>
          <span>StockMate</span>
        </div>
        <h1>Kelola stok tanpa angka yang simpang siur.</h1>
        <p>
          Catat produk, atur kategori, dan pantau setiap stok masuk dan keluar dalam satu
          tempat. Riwayat tersimpan rapi dan stok tidak pernah minus.
        </p>
        <ul className="auth-points">
          <li>Stok masuk/keluar tercatat atomik</li>
          <li>Peringatan produk stok menipis</li>
          <li>Data terpisah untuk setiap akun</li>
        </ul>
      </section>

      <section className="auth-panel">
        <div className="auth-card">
          <Outlet />
        </div>
        <p className="auth-footnote">StockMate — Simple Inventory Management System</p>
      </section>
    </div>
  );
}
