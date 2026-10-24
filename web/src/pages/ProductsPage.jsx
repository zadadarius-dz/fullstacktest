import { useCallback, useEffect, useState } from 'react';
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router-dom';
import { categoriesApi } from '../api/categories';
import { productsApi } from '../api/products';
import Alert from '../components/Alert';
import EmptyState from '../components/EmptyState';
import Pagination from '../components/Pagination';
import Spinner from '../components/Spinner';
import { formatCurrency, formatNumber } from '../utils/format';

const PAGE_SIZE = 10;

export default function ProductsPage() {
  const [searchParams] = useSearchParams();
  const location = useLocation();
  const navigate = useNavigate();

  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [page, setPage] = useState(1);
  const [totalItems, setTotalItems] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [searchInput, setSearchInput] = useState(searchParams.get('search') || '');
  const [search, setSearch] = useState(searchParams.get('search') || '');
  const [categoryId, setCategoryId] = useState(searchParams.get('categoryId') || '');
  const [lowStock, setLowStock] = useState(searchParams.get('lowStock') === 'true');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState(location.state?.message || '');

  useEffect(() => {
    if (!location.state?.message) return;
    navigate(location.pathname, { replace: true, state: null });
  }, [location, navigate]);

  useEffect(() => {
    let active = true;
    categoriesApi
      .list()
      .then((data) => {
        if (active) setCategories(data);
      })
      .catch(() => {
        if (active) setCategories([]);
      });
    return () => {
      active = false;
    };
  }, []);

  const loadProducts = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const data = await productsApi.list({
        page,
        pageSize: PAGE_SIZE,
        search,
        categoryId,
        lowStock,
      });
      setProducts(data.items);
      setTotalItems(data.totalItems);
      setTotalPages(data.totalPages);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [page, search, categoryId, lowStock]);

  useEffect(() => {
    loadProducts();
  }, [loadProducts]);

  const applyFilters = (event) => {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  };

  const handleDelete = async (product) => {
    if (!window.confirm(`Hapus produk "${product.name}"? Produk akan dinonaktifkan dan riwayat stok tetap tersimpan.`)) {
      return;
    }

    setNotice('');
    setError('');
    try {
      await productsApi.remove(product.id);
      setNotice(`Produk "${product.name}" berhasil dihapus.`);
      if (products.length === 1 && page > 1) {
        setPage((current) => current - 1);
      } else {
        await loadProducts();
      }
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="stack-lg">
      <header className="page-header">
        <div>
          <p className="eyebrow">Inventaris</p>
          <h1>Produk</h1>
          <p className="muted">Cari, filter, dan kelola seluruh produk aktif.</p>
        </div>
        <Link to="/products/new" className="btn btn-primary">+ Produk baru</Link>
      </header>

      {notice ? <Alert type="success" onClose={() => setNotice('')}>{notice}</Alert> : null}
      {error ? <Alert type="error" onClose={() => setError('')}>{error}</Alert> : null}

      <section className="card">
        <form className="filters" onSubmit={applyFilters}>
          <label className="field field-grow">
            <span>Cari produk</span>
            <input
              type="search"
              value={searchInput}
              onChange={(event) => setSearchInput(event.target.value)}
              placeholder="Nama atau SKU..."
            />
          </label>

          <label className="field">
            <span>Kategori</span>
            <select
              value={categoryId}
              onChange={(event) => {
                setCategoryId(event.target.value);
                setPage(1);
              }}
            >
              <option value="">Semua kategori</option>
              {categories.map((category) => (
                <option key={category.id} value={category.id}>{category.name}</option>
              ))}
            </select>
          </label>

          <label className="checkbox-field">
            <input
              type="checkbox"
              checked={lowStock}
              onChange={(event) => {
                setLowStock(event.target.checked);
                setPage(1);
              }}
            />
            Hanya stok menipis
          </label>

          <button type="submit" className="btn btn-secondary">Cari</button>
        </form>
      </section>

      {loading ? (
        <Spinner label="Memuat produk..." />
      ) : products.length === 0 ? (
        <EmptyState
          title="Tidak ada produk"
          description="Ubah filter pencarian atau tambahkan produk baru."
          action={<Link to="/products/new" className="btn btn-primary">Tambah produk</Link>}
        />
      ) : (
        <section className="card card-flush">
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>SKU</th>
                  <th>Produk</th>
                  <th>Kategori</th>
                  <th className="text-right">Harga</th>
                  <th className="text-right">Stok</th>
                  <th className="text-right">Min.</th>
                  <th className="text-right">Aksi</th>
                </tr>
              </thead>
              <tbody>
                {products.map((product) => {
                  const isLow = product.stockQuantity <= product.minStock;
                  return (
                    <tr key={product.id}>
                      <td className="mono">{product.sku}</td>
                      <td>
                        <Link className="table-link" to={`/products/${product.id}`}>{product.name}</Link>
                      </td>
                      <td className="muted">{product.categoryName}</td>
                      <td className="text-right">{formatCurrency(product.price)}</td>
                      <td className="text-right">
                        <span className={`badge ${isLow ? 'badge-warning' : 'badge-neutral'}`}>
                          {formatNumber(product.stockQuantity)}
                        </span>
                      </td>
                      <td className="text-right">{formatNumber(product.minStock)}</td>
                      <td>
                        <div className="row-actions">
                          <Link to={`/products/${product.id}`} className="btn btn-secondary btn-sm">Stok</Link>
                          <Link to={`/products/${product.id}/edit`} className="btn btn-secondary btn-sm">Edit</Link>
                          <button type="button" className="btn btn-danger btn-sm" onClick={() => handleDelete(product)}>
                            Hapus
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <Pagination
            page={page}
            totalPages={totalPages}
            totalItems={totalItems}
            pageSize={PAGE_SIZE}
            onPageChange={setPage}
          />
        </section>
      )}
    </div>
  );
}
