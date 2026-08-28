-- Idempotent: safe to re-run on retries or cluster resets
CREATE TABLE IF NOT EXISTS users (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

INSERT INTO users (name)
SELECT 'Mohamed'
WHERE NOT EXISTS (SELECT 1 FROM users);
