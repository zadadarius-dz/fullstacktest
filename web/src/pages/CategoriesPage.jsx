import { useCallback, useEffect, useState } from 'react';
import { categoriesApi } from '../api/categories';
import Alert from '../components/Alert';
import EmptyState from '../components/EmptyState';
import Modal from '../components/Modal';
import Spinner from '../components/Spinner';
import { formatDateTime } from '../utils/format';
import { validateCategoryName } from '../utils/validation';

export default function CategoriesPage() {
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState(null);
  const [name, setName] = useState('');
  const [formError, setFormError] = useState('');
  const [saving, setSaving] = useState(false);

  const loadCategories = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      setCategories(await categoriesApi.list());
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadCategories();
  }, [loadCategories]);

  const openCreate = () => {
    setEditing(null);
    setName('');
    setFormError('');
    setModalOpen(true);
  };

  const openEdit = (category) => {
    setEditing(category);
    setName(category.name);
    setFormError('');
    setModalOpen(true);
  };

  const closeModal = () => {
    if (saving) return;
    setModalOpen(false);
    setEditing(null);
    setFormError('');
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    const validationError = validateCategoryName(name);
    if (validationError) {
      setFormError(validationError);
      return;
    }

    setSaving(true);
    setFormError('');
    try {
      if (editing) {
        await categoriesApi.update(editing.id, { name: name.trim() });
        setNotice('Kategori berhasil diperbarui.');
      } else {
        await categoriesApi.create({ name: name.trim() });
        setNotice('Kategori berhasil dibuat.');
      }
      setModalOpen(false);
      setEditing(null);
      await loadCategories();
    } catch (err) {
      setFormError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (category) => {
    if (!window.confirm(`Hapus kategori "${category.name}"? Kategori yang masih dipakai produk tidak dapat dihapus.`)) {
      return;
    }

    setError('');
    setNotice('');
    try {
      await categoriesApi.remove(category.id);
      setNotice('Kategori berhasil dihapus.');
      await loadCategories();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="stack-lg">
      <header className="page-header">
        <div>
          <p className="eyebrow">Master data</p>
          <h1>Kategori</h1>
          <p className="muted">Kelompokkan produk agar pencarian dan laporan lebih rapi.</p>
        </div>
        <button type="button" className="btn btn-primary" onClick={openCreate}>
          + Kategori baru
        </button>
      </header>

      {notice ? <Alert type="success" onClose={() => setNotice('')}>{notice}</Alert> : null}
      {error ? <Alert type="error" onClose={() => setError('')}>{error}</Alert> : null}

      {loading ? (
        <Spinner label="Memuat kategori..." />
      ) : categories.length === 0 ? (
        <EmptyState
          title="Belum ada kategori"
          description="Buat kategori pertama sebelum menambahkan produk."
          action={
            <button type="button" className="btn btn-primary" onClick={openCreate}>
              Buat kategori
            </button>
          }
        />
      ) : (
        <div className="card card-flush">
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Nama kategori</th>
                  <th>Dibuat</th>
                  <th>Diperbarui</th>
                  <th className="text-right">Aksi</th>
                </tr>
              </thead>
              <tbody>
                {categories.map((category) => (
                  <tr key={category.id}>
                    <td><strong>{category.name}</strong></td>
                    <td className="muted">{formatDateTime(category.createdAt)}</td>
                    <td className="muted">{formatDateTime(category.updatedAt)}</td>
                    <td>
                      <div className="row-actions">
                        <button type="button" className="btn btn-secondary btn-sm" onClick={() => openEdit(category)}>
                          Edit
                        </button>
                        <button type="button" className="btn btn-danger btn-sm" onClick={() => handleDelete(category)}>
                          Hapus
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      <Modal
        open={modalOpen}
        title={editing ? 'Edit kategori' : 'Kategori baru'}
        onClose={closeModal}
        footer={(
          <>
            <button type="button" className="btn btn-secondary" onClick={closeModal} disabled={saving}>
              Batal
            </button>
            <button type="submit" form="category-form" className="btn btn-primary" disabled={saving}>
              {saving ? 'Menyimpan...' : 'Simpan'}
            </button>
          </>
        )}
      >
        <form id="category-form" className="stack" onSubmit={handleSubmit} noValidate>
          {formError ? <Alert type="error">{formError}</Alert> : null}
          <label className="field">
            <span>Nama kategori</span>
            <input
              type="text"
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder="Contoh: Minuman"
              maxLength={80}
              autoFocus
            />
            <small className="helper-text">2–80 karakter. Nama unik per akun.</small>
          </label>
        </form>
      </Modal>
    </div>
  );
}
