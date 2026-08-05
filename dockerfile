# 1. Base image: Minimal Python runtime on Debian
FROM python:3.11-slim

# 2. Prevent Python from buffering stdout/stderr and writing .pyc compiled bytecode files
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# 3. Create a designated non-root user and group (security best practice)
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app -s /sbin/nologin appuser

# 4. Set working directory
WORKDIR /app

# 5. Copy requirements first to leverage Docker Layer Caching
COPY requirements.txt ./

# 6. Install dependencies without accumulating cached downloaded tarballs
RUN pip install --no-cache-dir -r requirements.txt

# 7. Copy application source code into the container and assign ownership to non-root user
COPY --chown=appuser:appgroup app.py ./

# 8. Drop root privileges immediately by switching to the unprivileged user
USER appuser

# 9. Document application network port
EXPOSE 5000

# 10. Start the server
CMD ["python", "app.py"]