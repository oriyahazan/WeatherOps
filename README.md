# WeatherOps

WeatherOps is a FastAPI weather dashboard with current conditions and a five-day forecast, including today. Search for a city or select a suggested city to see temperature, feels-like temperature, humidity, wind, and the daily chance of precipitation. Temperatures are in Celsius and wind speed is in km/h.

## Run locally

Use Python 3.12 and run these commands from the repository root with the existing virtual environment. If you are setting up a fresh checkout, create it first with `python3.12 -m venv .venv`.

```bash
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m uvicorn app.main:app --reload
```

Open <http://127.0.0.1:8000>. City searches need an internet connection to Open-Meteo. The dashboard and healthcheck can load without access to the provider.

## Endpoints

| Endpoint | Purpose |
| --- | --- |
| `GET /` | Weather dashboard |
| `GET /api/info` | Application name, version, and data provider |
| `GET /healthcheck` | Local liveness check |
| `GET /weather?city=London` | Resolved location and current conditions |
| `GET /forecast?city=London` | Resolved location and five daily forecasts |
| `GET /docs` | Interactive API documentation |

City searches use the first geocoding match. Include a country or region qualifier for ambiguous names, such as `Paris, France`. The API returns 400 or 422 for invalid input, 404 when a city cannot be found, 502 for provider failures, and 504 for provider timeouts.

## Configuration

Export these optional environment variables before starting the app.

| Variable | Default |
| --- | --- |
| `WEATHEROPS_GEOCODING_URL` | `https://geocoding-api.open-meteo.com/v1/search` |
| `WEATHEROPS_FORECAST_URL` | `https://api.open-meteo.com/v1/forecast` |
| `WEATHEROPS_TIMEOUT_SECONDS` | `5` seconds per HTTPX connect, read, write, and pool operation |

## Architecture and tests

`app/main.py` serves the dashboard and assets from `app/static/` and manages the HTTPX client. `app/routes.py` defines the API and validates city input. `app/open_meteo.py` handles configuration and provider requests, and `app/models.py` defines the response schemas.

```bash
.venv/bin/python -m pytest -q
```

The tests use HTTPX's mock transport and run offline. Weather and location data come from [Open-Meteo](https://open-meteo.com/).
