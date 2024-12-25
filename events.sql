CREATE SCHEMA IF NOT EXISTS message_store;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS message_store.messages (
  category text NOT NULL,
  object_id text NOT NULL,
  type text NOT NULL,
  data bytea NOT NULL,
  time TIMESTAMP WITHOUT TIME ZONE DEFAULT (now() AT TIME ZONE 'utc') NOT NULL,
  PRIMARY KEY (category, object_id, type, time, data)
);

CREATE OR REPLACE FUNCTION message_store.hash_64(
  value varchar
)
RETURNS bigint
AS $$
DECLARE
  _hash bigint;
BEGIN
  SELECT left('x' || md5(hash_64.value), 17)::bit(64)::bigint INTO _hash;
  return _hash;
END;
$$ LANGUAGE plpgsql
IMMUTABLE;

CREATE OR REPLACE FUNCTION message_store.acquire_lock(category text)
RETURNS bigint
AS $$
DECLARE
  _category_name_hash bigint;
BEGIN
  _category_name_hash := message_store.hash_64(category);
  PERFORM pg_advisory_xact_lock(_category_name_hash);
  RETURN _category_name_hash;
END;
$$ LANGUAGE plpgsql
VOLATILE;

CREATE OR REPLACE PROCEDURE message_store.transact(
  category text,
  object_id text,
  "type" text,
  data bytea
)
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM message_store.acquire_lock(category);

  INSERT INTO message_store.messages
    (
      category,
      object_id,
      type,
      data
    )
  VALUES
    (
      category,
      object_id,
      type,
      data
    );

END;
$$;
