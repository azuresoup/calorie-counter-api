-- Расширения
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- USERS
-- =====================================================
CREATE TABLE users (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    login               VARCHAR(64) NOT NULL UNIQUE,
    password_hash       VARCHAR(255) NOT NULL,
    daily_calorie_goal  NUMERIC(8, 2),
    daily_protein_goal  NUMERIC(8, 2),
    daily_fat_goal      NUMERIC(8, 2),
    daily_carbs_goal    NUMERIC(8, 2),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- BRANDS
-- =====================================================
CREATE TABLE brands (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(128) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- PRODUCTS
-- =====================================================
CREATE TABLE products (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                  VARCHAR(255) NOT NULL,
    brand_id              UUID REFERENCES brands (id) ON DELETE SET NULL,
    barcode               VARCHAR(32),
    calories              NUMERIC(8, 2),
    protein               NUMERIC(8, 2),
    fat                   NUMERIC(8, 2),
    carbs                 NUMERIC(8, 2),
    fiber                 NUMERIC(8, 2),
    salt                  NUMERIC(8, 2),
    default_serving_grams NUMERIC(8, 2),
    favorite              BOOLEAN NOT NULL DEFAULT FALSE,
    image                 BYTEA,
    image_mime            VARCHAR(64),
    comment               TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at           TIMESTAMPTZ,
    deleted_at            TIMESTAMPTZ,
    -- картинка и mime либо оба заполнены, либо оба NULL
    CHECK ((image IS NULL) = (image_mime IS NULL))
);

-- частичный индекс для запросов только по живым продуктам
CREATE INDEX idx_products_alive ON products (id) WHERE deleted_at IS NULL;

-- индекс для поиска по штрихкоду
CREATE INDEX idx_products_barcode ON products (barcode)
    WHERE barcode IS NOT NULL AND deleted_at IS NULL;

-- индекс для FK на бренд
CREATE INDEX idx_products_brand ON products (brand_id)
    WHERE brand_id IS NOT NULL;

-- =====================================================
-- PRODUCT TAGS
-- =====================================================
CREATE TABLE product_tags (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE product_tag_relations (
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    tag_id     UUID NOT NULL REFERENCES product_tags (id) ON DELETE CASCADE,
    PRIMARY KEY (product_id, tag_id)
);

CREATE INDEX idx_product_tag_relations_tag ON product_tag_relations (tag_id);

-- =====================================================
-- RECIPE CATEGORIES
-- =====================================================
CREATE TABLE recipe_categories (
    id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) NOT NULL UNIQUE
);

-- =====================================================
-- RECIPES
-- =====================================================
CREATE TABLE recipes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL,
    comment         TEXT,
    source          TEXT,
    category_id     UUID REFERENCES recipe_categories (id) ON DELETE SET NULL,
    total_grams     NUMERIC(10, 2),
    servings        NUMERIC(8, 2),
    is_template     BOOLEAN NOT NULL DEFAULT FALSE,
    cloned_from_id  UUID REFERENCES recipes (id) ON DELETE SET NULL,
    image           BYTEA,
    image_mime      VARCHAR(64),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at     TIMESTAMPTZ,
    deleted_at      TIMESTAMPTZ,
    CHECK ((image IS NULL) = (image_mime IS NULL))
);

-- частичный индекс для шаблонов (часто запрашиваются отдельно)
CREATE INDEX idx_recipes_templates ON recipes (id)
    WHERE is_template = TRUE AND deleted_at IS NULL;

-- индекс для живых не-шаблонов (для листинга в журнале)
CREATE INDEX idx_recipes_alive ON recipes (id)
    WHERE is_template = FALSE AND deleted_at IS NULL;

-- индекс на cloned_from_id для поиска "все клоны этого шаблона"
CREATE INDEX idx_recipes_cloned_from ON recipes (cloned_from_id)
    WHERE cloned_from_id IS NOT NULL;

-- =====================================================
-- RECIPE PRODUCTS (ингредиенты рецепта)
-- =====================================================
CREATE TABLE recipe_products (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id  UUID NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    -- RESTRICT, потому что нельзя удалить продукт, на который ссылается рецепт.
    -- Soft delete продукта это не блокирует (deleted_at просто ставится).
    product_id UUID NOT NULL REFERENCES products (id) ON DELETE RESTRICT,
    grams      NUMERIC(10, 2) NOT NULL
);

CREATE INDEX idx_recipe_products_recipe ON recipe_products (recipe_id);
CREATE INDEX idx_recipe_products_product ON recipe_products (product_id);

-- =====================================================
-- ENUMS, общие для журнала и шаблонов еды
-- =====================================================
CREATE TYPE journal_unit AS ENUM ('grams', 'servings');
CREATE TYPE meal_type    AS ENUM ('breakfast', 'lunch', 'dinner', 'snack');

-- =====================================================
-- MEAL TEMPLATES (шаблоны еды — наборы продуктов/рецептов)
-- =====================================================
CREATE TABLE meal_templates (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name       VARCHAR(255) NOT NULL,
    comment    TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_meal_templates_user ON meal_templates (user_id)
    WHERE deleted_at IS NULL;

CREATE TABLE meal_template_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES meal_templates (id) ON DELETE CASCADE,
    product_id  UUID REFERENCES products (id) ON DELETE RESTRICT,
    recipe_id   UUID REFERENCES recipes (id) ON DELETE RESTRICT,
    amount      NUMERIC(10, 2),  -- nullable: если NULL, юзер вводит при применении
    unit        journal_unit NOT NULL,
    position    SMALLINT,        -- порядок в шаблоне
    -- ровно одно из product_id / recipe_id заполнено
    CHECK ((product_id IS NULL) <> (recipe_id IS NULL))
);

CREATE INDEX idx_meal_template_items_template ON meal_template_items (template_id);

-- =====================================================
-- JOURNAL ENTRIES
-- =====================================================
CREATE TABLE journal_entries (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    eaten_at   TIMESTAMPTZ NOT NULL,
    meal_type  meal_type NOT NULL,
    product_id UUID REFERENCES products (id) ON DELETE RESTRICT,
    recipe_id  UUID REFERENCES recipes (id) ON DELETE RESTRICT,
    amount     NUMERIC(10, 2) NOT NULL,
    unit       journal_unit NOT NULL,
    comment    TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    -- ровно одно из product_id / recipe_id заполнено
    CHECK ((product_id IS NULL) <> (recipe_id IS NULL))
);

-- основной индекс для статистики и листинга по юзеру за период
CREATE INDEX idx_journal_user_eaten ON journal_entries (user_id, eaten_at DESC)
    WHERE deleted_at IS NULL;

-- индексы на FK для быстрых JOIN'ов при расчётах
CREATE INDEX idx_journal_product ON journal_entries (product_id)
    WHERE product_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_journal_recipe ON journal_entries (recipe_id)
    WHERE recipe_id IS NOT NULL AND deleted_at IS NULL;

-- =====================================================
-- Триггер для автоматического обновления updated_at
-- =====================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_set_updated_at           BEFORE UPDATE ON users           FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER products_set_updated_at        BEFORE UPDATE ON products        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER recipes_set_updated_at         BEFORE UPDATE ON recipes         FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER meal_templates_set_updated_at  BEFORE UPDATE ON meal_templates  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER journal_entries_set_updated_at BEFORE UPDATE ON journal_entries FOR EACH ROW EXECUTE FUNCTION set_updated_at();
