# PostgreSQL Database & Persistence

This document details the database architecture, seeding logic, and backup mechanisms in the Halan Internship Project.

## 🗄️ Architecture & StatefulSets

We deploy PostgreSQL using the official Bitnami Helm chart with custom values (`helm/postgres/postgres-values.yaml`).

Instead of a standard `Deployment`, the database runs as a **StatefulSet**. This is critical for databases because:
1. **Stable Network ID**: Pods get predictable DNS names (e.g., `halan-db-postgresql-0`) instead of random hashes.
2. **Ordered Operations**: Pods are created, updated, and deleted in strict order.
3. **Persistent Volume Claims (PVC)**: Each pod gets its own dedicated PVC that survives pod restarts or rescheduling.

### Storage via Longhorn
Kubernetes does not provide distributed block storage natively. We use **Longhorn** as our `StorageClass`. It handles data replication across cluster nodes, ensuring that if an EC2 instance dies, the database data is not lost.

## 💧 Idempotent Seeding & DRY Principles

When a database is first created, it needs an initial schema and seed data.

### The Canonical Source of Truth
The SQL initialization script lives at `db/init/01-init.sql`. 
To avoid **DRY (Don't Repeat Yourself)** violations, the Helm chart responsible for running the seed job (`helm/db-seed/`) uses a **symlink** (`helm/db-seed/sql/01-init.sql -> ../../../../../db/init/01-init.sql`).
- This means there is only *one* actual SQL file in the entire repository.
- Git tracks symlinks natively (mode `120000`).
- When ArgoCD or Helm renders the chart, it follows the symlink and reads the correct SQL content.

### Idempotency (`WHERE NOT EXISTS`)
Kubernetes Jobs can fail and retry. If our SQL script contained a standard `INSERT INTO users (name) VALUES ('Mohamed');`, a retry would cause a failure or duplicate row.

We wrote the SQL to be **idempotent** (safe to run multiple times):
```sql
INSERT INTO users (name)
SELECT 'Mohamed'
WHERE NOT EXISTS (SELECT 1 FROM users);
```

## 🛡️ Daily Backup CronJob

In production, databases must be backed up automatically. We implemented a native Kubernetes `CronJob` (`infra/k8s/cronjob.yaml`) to handle this.

**Features of the Backup CronJob:**
- **Schedule:** Runs daily at `02:00 UTC` (`0 2 * * *`).
- **Security:** Pulls the database password directly from the `halan-db-secret` Kubernetes Secret. No plaintext passwords in scripts.
- **Execution:** Uses a lightweight `postgres:16-alpine` image to run `pg_dump`.
- **Compression:** Pipes the SQL output through `gzip` to significantly reduce file size (`.sql.gz`).
- **Persistence:** Mounts a dedicated 5Gi PVC (`db-backup-pvc.yaml`) using the `longhorn` storage class.
- **Auto-Pruning:** Includes a step to find and delete backups older than 7 days, preventing the PVC from filling up.
- **Restart Policy:** Uses `restartPolicy: OnFailure`. If the `pg_dump` fails (e.g., network blip), Kubernetes will automatically restart the pod to try again.
