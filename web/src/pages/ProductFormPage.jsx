import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { categoriesApi } from '../api/categories';
import { productsApi } from '../api/products';
import Alert from '../components/Alert';
import Spinner from '../components/Spinner';
import { validateProduct } from '../utils/validation';

const emptyForm = {
  sku: '',
  name: '',
  categoryId: '',
  description: '',
  price: '0',
  minStock: '0',
  isActive: true,
};

export default function ProductFormPage() {
  const { id } = useParams();
  const isEdit = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm] = useState(emptyForm);
  const [categories, setCategories] = useState([]);
  const [errors, setErrors] = useState({});
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [stockInfo, setStockInfo] = useState(null);

  useEffect(() => {
    let active = true;

    const load = async () => {
      setLoading(true);
      setError('');
      try {
        const [categoryList, product] = await Promise.all([
          categoriesApi.list(),
          isEdit ? productsApi.get(id) : Promise.resolve(null),
        ]);

        if (!active) return;
        setCategories(categoryList);

        if (product) {
          setForm({
            sku: product.sku,
            name: product.name,
            categoryId: product.categoryId,
            description: product.description || '',
            price: String(product.price),
            minStock: String(product.minStock),
            isActive: product.isActive,
          });
          setStockInfo({ stockQuantity: product.stockQuantity });
        } else if (categoryList.length > 0) {
          setForm((current) => ({ ...current, categoryId: categoryList[0].id }));
        }
      } catch (err) {
        if (active) setError(err.message);
      } finally {
        if (active) setLoading(false);
      }
    };

    load();
    return () => {
      active = false;
    };
  }, [id, isEdit]);

  const handleChange = (event) => {
    const { name, value, type, checked } = event.target;
    setForm((current) => ({ ...current, [name]: type === 'checkbox' ? checked : value }));
    setErrors((current) => ({ ...current, [name]: undefined }));
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError('');

    const validationErrors = validateProduct(form);
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors);
      return;
    }

    const payload = {
      sku: form.sku.trim(),
      name: form.name.trim(),
      categoryId: form.categoryId,
      description: form.description.trim() || null,
      price: Number(form.price),
      minStock: Number(form.minStock),
    };

    if (isEdit) {
      payload.isActive = form.isActive;
    }

    setSaving(true);
    try {
      if (isEdit) {
        await productsApi.update(id, payload);
        navigate('/products', { state: { message: 'Produk berhasil diperbarui. Stok tidak berubah.' } });
      } else {
        await productsApi.create(payload);
        navigate('/products', { state: { message: 'Produk berhasil dibuat dengan stok awal 0.' } });
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <Spinner label={isEdit ? 'Memuat produk...' : 'Menyiapkan form...'} />;
  }

  return (
    <div className="stack-lg">
      <header className="page-header">
        <div>
          <p className="eyebrow">{isEdit ? 'Edit produk' : 'Produk baru'}</p>
          <h1>{isEdit ? form.name || 'Edit produk' : 'Tambah produk'}</h1>
          <p className="muted">
            {isEdit
              ? 'Perubahan di sini tidak mengubah jumlah stok. Gunakan halaman detail untuk mencatat stok.'
              : 'Stok awal produk selalu 0. Stok diubah melalui transaksi masuk/keluar.'}
          </p>
        </div>
        <Link to="/products" className="btn btn-secondary">Kembali</Link>
      </header>

      {error ? <Alert type="error" onClose={() => setError('')}>{error}</Alert> : null}

      {categories.length === 0 ? (
        <Alert type="warning" title="Belum ada kategori">
          Buat kategori terlebih dahulu di <Link to="/categories">halaman kategori</Link>.
        </Alert>
      ) : null}

      {stockInfo ? (
        <Alert type="info" title="Stok saat ini">
          Stok tercatat: <strong>{stockInfo.stockQuantity}</strong>. Jumlah ini hanya dapat berubah
          melalui transaksi stok.
        </Alert>
      ) : null}

      <form className="card stack-lg" onSubmit={handleSubmit} noValidate>
        <div className="form-grid form-grid-2">
          <label className="field">
            <span>SKU</span>
            <input
              type="text"
              name="sku"
              value={form.sku}
              onChange={handleChange}
              placeholder="Contoh: KOPI-001"
              maxLength={64}
              className={errors.sku ? 'has-error' : ''}
              disabled={saving}
            />
            {errors.sku ? <small className="field-error">{errors.sku}</small> : null}
          </label>

          <label className="field">
            <span>Nama produk</span>
            <input
              type="text"
              name="name"
              value={form.name}
              onChange={handleChange}
              placeholder="Contoh: Kopi Arabica 250g"
              maxLength={160}
              className={errors.name ? 'has-error' : ''}
              disabled={saving}
            />
            {errors.name ? <small className="field-error">{errors.name}</small> : null}
          </label>

          <label className="field">
            <span>Kategori</span>
            <select
              name="categoryId"
              value={form.categoryId}
              onChange={handleChange}
              className={errors.categoryId ? 'has-error' : ''}
              disabled={saving || categories.length === 0}
            >
              <option value="">Pilih kategori</option>
              {categories.map((category) => (
                <option key={category.id} value={category.id}>{category.name}</option>
              ))}
            </select>
            {errors.categoryId ? <small className="field-error">{errors.categoryId}</small> : null}
          </label>

          <label className="field">
            <span>Harga (Rp)</span>
            <input
              type="number"
              name="price"
              value={form.price}
              onChange={handleChange}
              min="0"
              step="0.01"
              className={errors.price ? 'has-error' : ''}
              disabled={saving}
            />
            {errors.price ? <small className="field-error">{errors.price}</small> : null}
          </label>

          <label className="field">
            <span>Stok minimum</span>
            <input
              type="number"
              name="minStock"
              value={form.minStock}
              onChange={handleChange}
              min="0"
              step="1"
              className={errors.minStock ? 'has-error' : ''}
              disabled={saving}
            />
            <small className="helper-text">Produk ditandai menipis bila stok ≤ nilai ini.</small>
            {errors.minStock ? <small className="field-error">{errors.minStock}</small> : null}
          </label>

          {isEdit ? (
            <label className="checkbox-field checkbox-field-card">
              <input
                type="checkbox"
                name="isActive"
                checked={form.isActive}
                onChange={handleChange}
                disabled={saving}
              />
              Produk aktif
            </label>
          ) : null}
        </div>

        <label className="field">
          <span>Deskripsi (opsional)</span>
          <textarea
            name="description"
            value={form.description}
            onChange={handleChange}
            rows={4}
            maxLength={500}
            className={errors.description ? 'has-error' : ''}
            disabled={saving}
          />
          <small className="helper-text">{form.description.length}/500 karakter</small>
          {errors.description ? <small className="field-error">{errors.description}</small> : null}
        </label>

        <div className="form-actions">
          <Link to="/products" className="btn btn-secondary">Batal</Link>
          <button type="submit" className="btn btn-primary" disabled={saving || categories.length === 0}>
            {saving ? 'Menyimpan...' : isEdit ? 'Simpan perubahan' : 'Buat produk'}
          </button>
        </div>
      </form>
    </div>
  );
}
