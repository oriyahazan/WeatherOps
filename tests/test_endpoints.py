import httpx
import pytest
from fastapi.testclient import TestClient

from app.main import create_app


LOCATION = {"name": "London", "country": "United Kingdom", "latitude": 51.5, "longitude": -0.12}
CURRENT = {
    "time": "2026-11-19T12:00", "temperature_2m": 13.4, "apparent_temperature": 11.2,
    "relative_humidity_2m": 82, "wind_speed_10m": 14, "weather_code": 3, "is_day": 1,
}
DAILY = {
    "time": [f"2026-11-{day}" for day in range(19, 24)],
    "temperature_2m_max": [14, 15, 15, 12, 10],
    "temperature_2m_min": [7, 8, 8, 6, 5],
    "precipitation_probability_max": [10, 50, 25, 40, None],
    "weather_code": [1, 61, 3, 80, 2],
}


def client_for(handler):
    return TestClient(create_app(transport=httpx.MockTransport(handler)))


def unexpected_request(request):
    pytest.fail(f"Unexpected external request: {request.url}")


def test_dashboard_info_and_health_are_local():
    with client_for(unexpected_request) as client:
        page = client.get("/")
        assert page.status_code == 200
        assert page.headers["content-type"].startswith("text/html")
        assert "Let's check the weather." in page.text
        for asset in ("styles.css", "dashboard.js"):
            assert client.get(f"/static/{asset}").status_code == 200
        assert client.get("/healthcheck").json() == {"status": "ok"}
        assert client.get("/api/info").json()["provider"] == "Open-Meteo"


@pytest.mark.parametrize("path", ["/weather", "/forecast"])
def test_success(path):
    def handler(request):
        params = request.url.params
        if request.url.path == "/v1/search":
            assert params["name"] == "London"
            return httpx.Response(200, json={"results": [LOCATION]})
        assert request.url.path == "/v1/forecast"
        assert params["latitude"] == "51.5"
        assert params["timezone"] == "auto"
        if path == "/weather":
            assert "temperature_2m" in params["current"].split(",")
            assert "time" not in params["current"].split(",")
            return httpx.Response(200, json={"current": CURRENT})
        assert params["forecast_days"] == "5"
        assert "weather_code" in params["daily"].split(",")
        return httpx.Response(200, json={"daily": DAILY})

    with client_for(handler) as client:
        response = client.get(path, params={"city": " London "})
    assert response.status_code == 200
    payload = response.json()
    assert payload["location"]["name"] == "London"
    if path == "/weather":
        assert payload["current"]["temperature_2m"] == 13.4
    else:
        assert len(payload["days"]) == 5
        assert payload["days"][0]["time"] == "2026-11-19"
        assert payload["days"][-1]["precipitation_probability_max"] is None


@pytest.mark.parametrize("path", ["/weather", "/forecast"])
@pytest.mark.parametrize(("params", "code"), [
    ({}, 422), ({"city": "  "}, 400), ({"city": "123"}, 400), ({"city": "x" * 101}, 422),
])
def test_invalid_city(path, params, code):
    with client_for(unexpected_request) as client:
        assert client.get(path, params=params).status_code == code


@pytest.mark.parametrize("path", ["/weather", "/forecast"])
@pytest.mark.parametrize(("provider", "code"), [
    ("missing", 404), ("http", 502), ("timeout", 504),
    ("network", 502), ("invalid_json", 502), ("invalid_weather", 502),
])
def test_provider_errors(path, provider, code):
    def handler(request):
        if provider == "timeout":
            raise httpx.ReadTimeout("timed out", request=request)
        if provider == "network":
            raise httpx.ConnectError("connection failed", request=request)
        if provider == "http":
            return httpx.Response(503)
        if provider == "invalid_json":
            return httpx.Response(200, text="not json")
        if provider == "missing":
            assert request.url.path == "/v1/search"
            return httpx.Response(200, json={})
        if request.url.path == "/v1/search":
            return httpx.Response(200, json={"results": [LOCATION]})
        return httpx.Response(200, json={"current": {}, "daily": {"time": []}})

    with client_for(handler) as client:
        response = client.get(path, params={"city": "London"})
        assert response.status_code == code
        assert isinstance(response.json()["detail"], str)
        assert client.get("/healthcheck").status_code == 200
