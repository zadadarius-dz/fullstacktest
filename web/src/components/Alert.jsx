export default function Alert({ type = 'error', title, children, onClose }) {
  const labels = {
    error: 'Terjadi kesalahan',
    success: 'Berhasil',
    info: 'Informasi',
    warning: 'Perhatian',
  };

  return (
    <div className={`alert alert-${type}`} role={type === 'error' ? 'alert' : 'status'}>
      <div className="alert-body">
        <strong>{title || labels[type]}</strong>
        {children ? <div className="alert-message">{children}</div> : null}
      </div>
      {onClose ? (
        <button type="button" className="alert-close" onClick={onClose} aria-label="Tutup notifikasi">
          ×
        </button>
      ) : null}
    </div>
  );
}
