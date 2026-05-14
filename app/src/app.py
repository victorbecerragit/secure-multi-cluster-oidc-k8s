from flask import Flask

app = Flask(__name__)

@app.get("/")
def home():
    return {"message": "hello from EKS"}

@app.get("/healthz")
def healthz():
    return {"status": "ok"}

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8080)
