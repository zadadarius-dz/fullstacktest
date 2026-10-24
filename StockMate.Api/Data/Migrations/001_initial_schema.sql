-- =============================================================================
-- StockMate — Initial schema (PostgreSQL 13+; diuji pada PostgreSQL 18)
-- File: Data/Migrations/001_initial_schema.sql
--
-- Cara pakai:
--   psql "host=... dbname=... user=..." -f 001_initial_schema.sql
-- atau buka file ini di pgAdmin Query Tool lalu Execute.
--
-- Script ini idempoten (aman dijalankan ulang). Script TIDAK membuat database
-- dan TIDAK berisi password/credential. Buat database lebih dulu, lalu jalankan
-- script ini terhadap database tersebut.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- Fungsi trigger untuk memperbarui updated_at secara otomatis.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- users
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(255) NOT NULL,
    password_hash TEXT         NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_users_name_not_blank CHECK (length(btrim(name)) >= 2)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_email_lower
    ON users (lower(email));

-- -----------------------------------------------------------------------------
-- categories
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name       VARCHAR(80)  NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_categories_name_length CHECK (length(btrim(name)) BETWEEN 2 AND 80),
    -- Dibutuhkan oleh composite FK products(category_id, user_id) agar produk
    -- tidak dapat memakai kategori milik pengguna lain.
    CONSTRAINT uq_categories_id_user UNIQUE (id, user_id)
);

-- Nama kategori unik per pengguna tanpa membedakan kapitalisasi.
CREATE UNIQUE INDEX IF NOT EXISTS ux_categories_user_name_lower
    ON categories (user_id, lower(btrim(name)));

CREATE INDEX IF NOT EXISTS idx_categories_user_created
    ON categories (user_id, created_at DESC);

-- -----------------------------------------------------------------------------
-- products
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID           NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    category_id    UUID           NOT NULL,
    sku            VARCHAR(64)    NOT NULL,
    name           VARCHAR(160)   NOT NULL,
    description    VARCHAR(500)   NULL,
    price          NUMERIC(14, 2) NOT NULL DEFAULT 0,
    stock_quantity INTEGER        NOT NULL DEFAULT 0,
    min_stock      INTEGER        NOT NULL DEFAULT 0,
    is_active      BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_products_price_non_negative CHECK (price >= 0),
    CONSTRAINT chk_products_stock_non_negative CHECK (stock_quantity >= 0),
    CONSTRAINT chk_products_min_stock_non_negative CHECK (min_stock >= 0),
    CONSTRAINT chk_products_name_length CHECK (length(btrim(name)) BETWEEN 2 AND 160),
    CONSTRAINT chk_products_sku_not_blank CHECK (length(btrim(sku)) BETWEEN 1 AND 64),
    -- Composite FK: kategori harus ada DAN milik user yang sama dengan produk.
    CONSTRAINT fk_products_category_owner
        FOREIGN KEY (category_id, user_id) REFERENCES categories (id, user_id) ON DELETE RESTRICT,
    -- Dibutuhkan oleh composite FK stock_movements(product_id, created_by_user_id).
    CONSTRAINT uq_products_id_user UNIQUE (id, user_id)
);

-- SKU unik per pengguna (SKU disimpan uppercase oleh API).
CREATE UNIQUE INDEX IF NOT EXISTS ux_products_user_sku
    ON products (user_id, sku);

CREATE INDEX IF NOT EXISTS idx_products_user_active
    ON products (user_id, is_active, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_products_category
    ON products (category_id);

CREATE INDEX IF NOT EXISTS idx_products_user_name_lower
    ON products (user_id, lower(name));

CREATE INDEX IF NOT EXISTS idx_products_user_sku_lower
    ON products (user_id, lower(sku));

-- -----------------------------------------------------------------------------
-- stock_movements (append-only; tidak ada endpoint update/delete)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stock_movements (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id         UUID        NOT NULL,
    created_by_user_id UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type               VARCHAR(3)  NOT NULL,
    quantity           INTEGER     NOT NULL,
    stock_before       INTEGER     NOT NULL,
    stock_after        INTEGER     NOT NULL,
    note               VARCHAR(300) NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_stock_movements_type CHECK (type IN ('IN', 'OUT')),
    CONSTRAINT chk_stock_movements_quantity_positive CHECK (quantity > 0),
    CONSTRAINT chk_stock_movements_stock_before_non_negative CHECK (stock_before >= 0),
    CONSTRAINT chk_stock_movements_stock_after_non_negative CHECK (stock_after >= 0),
    CONSTRAINT chk_stock_movements_out_reduces_stock CHECK (type <> 'OUT' OR stock_after = stock_before - quantity),
    CONSTRAINT chk_stock_movements_in_increases_stock CHECK (type <> 'IN' OR stock_after = stock_before + quantity),
    -- Memastikan movement hanya dibuat oleh pemilik produk yang sama.
    CONSTRAINT fk_stock_movements_product_owner
        FOREIGN KEY (product_id, created_by_user_id) REFERENCES products (id, user_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_product_created
    ON stock_movements (product_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_stock_movements_user_created
    ON stock_movements (created_by_user_id, created_at DESC);

-- -----------------------------------------------------------------------------
-- Trigger updated_at
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_categories_updated_at ON categories;
CREATE TRIGGER trg_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
