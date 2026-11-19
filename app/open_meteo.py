import math
import os
from dataclasses import dataclass

import httpx
from fastapi import HTTPException
from pydantic import ValidationError

from .models import Current, ForecastDay, ForecastResponse, Location, WeatherResponse


@dataclass(frozen=True)
class Settings:
    geocoding_url: str
    forecast_url: str
    timeout: httpx.Timeout

    @classmethod
    def from_env(cls):
        seconds = float(os.getenv("WEATHEROPS_TIMEOUT_SECONDS", "5"))
        if not math.isfinite(seconds) or seconds <= 0:
            raise ValueError("WEATHEROPS_TIMEOUT_SECONDS must be a positive, finite number")
        return cls(
            geocoding_url=os.getenv(
                "WEATHEROPS_GEOCODING_URL", "https://geocoding-api.open-meteo.com/v1/search"
            ),
            forecast_url=os.getenv(
                "WEATHEROPS_FORECAST_URL", "https://api.open-meteo.com/v1/forecast"
            ),
            timeout=httpx.Timeout(seconds),
        )


def unavailable():
    return HTTPException(502, "Weather data is temporarily unavailable. Please try again.")


class OpenMeteo:
    def __init__(self, client: httpx.AsyncClient, settings: Settings):
        self.client = client
        self.settings = settings

    async def _get(self, url, params):
        try:
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            if not isinstance(data, dict) or data.get("error"):
                raise ValueError("Unexpected provider response")
            return data
        except httpx.TimeoutException as exc:
            raise HTTPException(504, "The weather service took too long. Please try again.") from exc
        except (httpx.HTTPError, ValueError) as exc:
            raise unavailable() from exc

    async def _location(self, city: str) -> Location:
        data = await self._get(
            self.settings.geocoding_url, {"name": city, "count": 1, "language": "en"}
        )
        results = data.get("results", [])
        if not isinstance(results, list):
            raise unavailable()
        if not results:
            raise HTTPException(404, "City not found. Check the spelling or try another city.")
        try:
            return Location.model_validate(results[0])
        except ValidationError as exc:
            raise unavailable() from exc

    async def _forecast_data(self, location: Location, **params):
        return await self._get(self.settings.forecast_url, {
            "latitude": location.latitude,
            "longitude": location.longitude,
            "timezone": "auto",
            "temperature_unit": "celsius",
            "wind_speed_unit": "kmh",
            **params,
        })

    async def weather(self, city: str) -> WeatherResponse:
        location = await self._location(city)
        fields = [field for field in Current.model_fields if field != "time"]
        data = await self._forecast_data(location, current=",".join(fields))
        try:
            current = Current.model_validate(data["current"])
        except (KeyError, ValidationError) as exc:
            raise unavailable() from exc
        return WeatherResponse(location=location, current=current)

    async def forecast(self, city: str) -> ForecastResponse:
        location = await self._location(city)
        fields = [field for field in ForecastDay.model_fields if field != "time"]
        data = await self._forecast_data(location, daily=",".join(fields), forecast_days=5)
        try:
            daily = data["daily"]
            columns = [daily[field] for field in ForecastDay.model_fields]
            if any(not isinstance(column, list) or len(column) != 5 for column in columns):
                raise ValueError("Expected five days per column")
            days = [
                ForecastDay.model_validate(dict(zip(ForecastDay.model_fields, row, strict=True)))
                for row in zip(*columns, strict=True)
            ]
        except (KeyError, TypeError, ValueError) as exc:
            raise unavailable() from exc
        return ForecastResponse(location=location, days=days)
