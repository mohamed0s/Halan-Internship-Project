import os
from flask import Flask, jsonify
import psycopg2

app = Flask(__name__)


def get_db_connection():
  return psycopg2.connect(
      host=os.environ.get("DB_HOST", "db"),
      database=os.environ.get("DB_NAME", "halandb"),
      user=os.environ.get("DB_USER", "pguser"),
      password=os.environ.get("DB_PASSWORD", "secretpass"),
      port=os.environ.get("DB_PORT", "5432"),
  )


@app.route("/")
@app.route("/api/name")
def get_name():
  try:
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT name FROM users LIMIT 1;")
    row = cur.fetchone()
    cur.close()
    conn.close()

    name = row[0] if row else "Unknown Developer"
    return jsonify({
        "status": "success",
        "name": name,
        "source": "PostgreSQL Database",
    })
  except Exception as e:
    return jsonify({"status": "error", "message": str(e)}), 500


if __name__ == "__main__":
  port = int(os.environ.get("PORT", 5000))
  app.run(host="0.0.0.0", port=port)
