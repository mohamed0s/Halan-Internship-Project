import os
from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello_world():
  return (
      "<h1>Hello World! Built by Mohamed in a secure non-root Docker"
      " Container!</h1>"
  )


if __name__ == "__main__":
  # Bind to 0.0.0.0 so the server is reachable outside the isolated container namespace
  port = int(os.environ.get("PORT", 5000))
  app.run(host="0.0.0.0", port=port)
