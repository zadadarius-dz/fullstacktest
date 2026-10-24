import { Link } from 'react-router-dom';

export default function NotFoundPage() {
  return (
    <div className="fullscreen-center">
      <div className="not-found">
        <span className="not-found-code">404</span>
        <h1>Halaman tidak ditemukan</h1>
        <p>Alamat yang Anda buka tidak tersedia atau sudah dipindahkan.</p>
        <Link className="btn btn-primary" to="/dashboard">Kembali ke dashboard</Link>
      </div>
    </div>
  );
}
