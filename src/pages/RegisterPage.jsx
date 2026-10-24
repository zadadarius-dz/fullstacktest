import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import Alert from '../components/Alert';
import { useAuth } from '../context/useAuth';

export default function RegisterPage() {
  const { register } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({
    name: '',
    email: '',
    password: '',
    confirmPassword: '',
  });
  const [errors, setErrors] = useState({});
  const [serverError, setServerError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleChange = (event) => {
    const { name, value } = event.target;
    setForm((current) => ({ ...current, [name]: value }));
    setErrors((current) => ({ ...current, [name]: undefined }));
  };

  const validate = () => {
    const next = {};
    if (form.name.trim().length < 2) next.name = 'Nama minimal 2 karakter.';
    else if (form.name.trim().length > 100) next.name = 'Nama maksimal 100 karakter.';

    if (!form.email.trim()) next.email = 'Email wajib diisi.';
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())) {
      next.email = 'Format email tidak valid.';
    }

    if (form.password.length < 8) next.password = 'Password minimal 8 karakter.';
    else if (form.password.length > 72) next.password = 'Password maksimal 72 karakter.';

    if (form.confirmPassword !== form.password) {
      next.confirmPassword = 'Konfirmasi password tidak sama.';
    }

    setErrors(next);
    return Object.keys(next).length === 0;
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setServerError('');
    if (!validate()) return;

    setSubmitting(true);
    try {
      await register(form.name.trim(), form.email.trim(), form.password);
      navigate('/dashboard', { replace: true });
    } catch (error) {
      setServerError(error.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="stack-lg">
      <div>
        <p className="eyebrow">Mulai dalam satu menit</p>
        <h1 className="auth-title">Buat akun StockMate</h1>
        <p className="muted">Satu akun untuk mengelola seluruh kategori, produk, dan riwayat stok Anda.</p>
      </div>

      {serverError ? <Alert type="error">{serverError}</Alert> : null}

      <form className="stack" onSubmit={handleSubmit} noValidate>
        <label className="field">
          <span>Nama lengkap</span>
          <input
            type="text"
            name="name"
            value={form.name}
            onChange={handleChange}
            autoComplete="name"
            placeholder="Nama Anda"
            className={errors.name ? 'has-error' : ''}
            disabled={submitting}
          />
          {errors.name ? <small className="field-error">{errors.name}</small> : null}
        </label>

        <label className="field">
          <span>Email</span>
          <input
            type="email"
            name="email"
            value={form.email}
            onChange={handleChange}
            autoComplete="email"
            placeholder="nama@perusahaan.com"
            className={errors.email ? 'has-error' : ''}
            disabled={submitting}
          />
          {errors.email ? <small className="field-error">{errors.email}</small> : null}
        </label>

        <div className="form-grid form-grid-2">
          <label className="field">
            <span>Password</span>
            <input
              type="password"
              name="password"
              value={form.password}
              onChange={handleChange}
              autoComplete="new-password"
              placeholder="Minimal 8 karakter"
              className={errors.password ? 'has-error' : ''}
              disabled={submitting}
            />
            {errors.password ? <small className="field-error">{errors.password}</small> : null}
          </label>

          <label className="field">
            <span>Konfirmasi password</span>
            <input
              type="password"
              name="confirmPassword"
              value={form.confirmPassword}
              onChange={handleChange}
              autoComplete="new-password"
              placeholder="Ulangi password"
              className={errors.confirmPassword ? 'has-error' : ''}
              disabled={submitting}
            />
            {errors.confirmPassword ? (
              <small className="field-error">{errors.confirmPassword}</small>
            ) : null}
          </label>
        </div>

        <button type="submit" className="btn btn-primary btn-block" disabled={submitting}>
          {submitting ? 'Membuat akun...' : 'Daftar'}
        </button>
      </form>

      <p className="auth-switch">
        Sudah punya akun? <Link to="/login">Masuk</Link>
      </p>
    </div>
  );
}
