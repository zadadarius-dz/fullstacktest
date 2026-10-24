import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/useAuth';

const navigation = [
  { to: '/dashboard', label: 'Dashboard', icon: '▦' },
  { to: '/products', label: 'Produk', icon: '▤' },
  { to: '/categories', label: 'Kategori', icon: '▥' },
  { to: '/movements', label: 'Riwayat Stok', icon: '⇄' },
];

export default function AppLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login', { replace: true });
  };

  const initial = (user?.name || '?').trim().charAt(0).toUpperCase();

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">S</span>
          <div>
            <strong>StockMate</strong>
            <span>Inventory sederhana</span>
          </div>
        </div>

        <nav className="sidebar-nav" aria-label="Navigasi utama">
          {navigation.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => `nav-link ${isActive ? 'is-active' : ''}`}
            >
              <span className="nav-icon" aria-hidden="true">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="user-card">
            <span className="avatar" aria-hidden="true">{initial}</span>
            <div className="user-meta">
              <strong>{user?.name || 'Pengguna'}</strong>
              <span>{user?.email || ''}</span>
            </div>
          </div>
          <button type="button" className="btn btn-ghost btn-block" onClick={handleLogout}>
            Keluar
          </button>
        </div>
      </aside>

      <div className="app-main">
        <header className="mobile-header">
          <div className="brand brand-mobile">
            <span className="brand-mark" aria-hidden="true">S</span>
            <strong>StockMate</strong>
          </div>
          <button type="button" className="btn btn-secondary btn-sm" onClick={handleLogout}>
            Keluar
          </button>
        </header>

        <nav className="mobile-nav" aria-label="Navigasi utama mobile">
          {navigation.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => `mobile-nav-link ${isActive ? 'is-active' : ''}`}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>

        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
