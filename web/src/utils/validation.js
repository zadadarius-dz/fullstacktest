export function validateCategoryName(name) {
  const value = (name || '').trim();
  if (value.length < 2) return 'Nama kategori minimal 2 karakter.';
  if (value.length > 80) return 'Nama kategori maksimal 80 karakter.';
  return null;
}

export function validateProduct(form) {
  const errors = {};
  const sku = (form.sku || '').trim();
  const name = (form.name || '').trim();
  const description = (form.description || '').trim();
  const price = Number(form.price);
  const minStock = Number(form.minStock);

  if (!sku) errors.sku = 'SKU wajib diisi.';
  else if (sku.length > 64) errors.sku = 'SKU maksimal 64 karakter.';

  if (name.length < 2) errors.name = 'Nama produk minimal 2 karakter.';
  else if (name.length > 160) errors.name = 'Nama produk maksimal 160 karakter.';

  if (!form.categoryId) errors.categoryId = 'Kategori wajib dipilih.';
  if (description.length > 500) errors.description = 'Deskripsi maksimal 500 karakter.';
  if (form.price === '' || !Number.isFinite(price) || price < 0) {
    errors.price = 'Harga harus 0 atau lebih.';
  }
  if (form.minStock === '' || !Number.isInteger(minStock) || minStock < 0) {
    errors.minStock = 'Stok minimum harus bilangan bulat 0 atau lebih.';
  }

  return errors;
}

export function validateMovement(form) {
  const errors = {};
  const quantity = Number(form.quantity);
  if (!['IN', 'OUT'].includes(form.type)) errors.type = 'Pilih tipe IN atau OUT.';
  if (!Number.isInteger(quantity) || quantity <= 0) {
    errors.quantity = 'Quantity harus bilangan bulat positif.';
  }
  if ((form.note || '').length > 300) errors.note = 'Catatan maksimal 300 karakter.';
  return errors;
}
