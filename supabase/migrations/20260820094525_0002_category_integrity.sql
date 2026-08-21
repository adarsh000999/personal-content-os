-- 1. Add composite UNIQUE constraint on categories
ALTER TABLE categories
  ADD CONSTRAINT categories_id_user_id_key UNIQUE (id, user_id);

-- 2. Replace categories.parent_id single-column FK with composite FK
ALTER TABLE categories
  DROP CONSTRAINT categories_parent_id_fkey;

ALTER TABLE categories
  ADD CONSTRAINT categories_parent_id_fkey
    FOREIGN KEY (parent_id, user_id)
    REFERENCES categories (id, user_id)
    ON DELETE SET NULL (parent_id);

-- 3. Replace content.category_id single-column FK with composite FK
ALTER TABLE content
  DROP CONSTRAINT content_category_id_fkey;

ALTER TABLE content
  ADD CONSTRAINT content_category_id_fkey
    FOREIGN KEY (category_id, user_id)
    REFERENCES categories (id, user_id)
    ON DELETE SET NULL (category_id);
