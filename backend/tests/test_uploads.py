import hashlib

import pytest
from fakes import TOKEN, UID, FakeSteps, FakeStore, verify_token
from fastapi.testclient import TestClient
from orchestrator.main import create_app
from orchestrator.uploads import CloudinarySigner

AUTH = {"Authorization": f"Bearer {TOKEN}"}
SIGNER = CloudinarySigner(cloud_name="demo", api_key="key-123", api_secret="secret-456")
FILE = "realtron_1706.03762.pdf"


def client_with(signer):
    return TestClient(create_app(FakeStore(), verify_token, FakeSteps(), signer))


def test_the_signature_follows_cloudinarys_scheme():
    ticket = SIGNER.sign(UID, FILE, now=1_700_000_000)

    expected = hashlib.sha1(
        f"public_id=reports/{UID}/{FILE}&timestamp=1700000000secret-456".encode()
    ).hexdigest()
    assert ticket == {
        "uploadUrl": "https://api.cloudinary.com/v1_1/demo/raw/upload",
        "fields": {
            "api_key": "key-123",
            "public_id": f"reports/{UID}/{FILE}",
            "timestamp": "1700000000",
            "signature": expected,
        },
    }


def test_the_secret_never_leaves_the_server():
    assert "secret-456" not in str(SIGNER.sign(UID, FILE))


def test_settings_come_from_the_environment(monkeypatch):
    monkeypatch.setenv("CLOUDINARY_CLOUD_NAME", "demo")
    monkeypatch.setenv("CLOUDINARY_API_KEY", "key-123")
    monkeypatch.setenv("CLOUDINARY_API_SECRET", "secret-456")
    assert CloudinarySigner.from_env() == SIGNER

    monkeypatch.delenv("CLOUDINARY_API_SECRET")
    assert CloudinarySigner.from_env() is None


def test_the_folder_comes_from_the_token_not_the_request():
    with client_with(SIGNER) as client:
        response = client.post("/api/uploads/signature", json={"fileName": FILE}, headers=AUTH)

    assert response.status_code == 200
    assert response.json()["fields"]["public_id"] == f"reports/{UID}/{FILE}"


@pytest.mark.parametrize("headers", [{}, {"Authorization": "Bearer wrong"}])
def test_signing_needs_a_valid_firebase_token(headers):
    with client_with(SIGNER) as client:
        response = client.post("/api/uploads/signature", json={"fileName": FILE}, headers=headers)
    assert response.status_code == 401


@pytest.mark.parametrize(
    "name", ["../other/realtron.pdf", "other_uid/realtron.pdf", "realtron.exe", "realtron", ""]
)
def test_only_a_plain_pdf_name_is_signed(name):
    with client_with(SIGNER) as client:
        response = client.post("/api/uploads/signature", json={"fileName": name}, headers=AUTH)
    assert response.status_code == 422


def test_without_cloudinary_settings_the_server_says_so():
    with client_with(None) as client:
        response = client.post("/api/uploads/signature", json={"fileName": FILE}, headers=AUTH)
    assert response.status_code == 503
