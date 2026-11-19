from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request

from .models import AppInfo, ForecastResponse, Health, WeatherResponse
from .open_meteo import OpenMeteo

router = APIRouter()


def city_name(city: Annotated[str, Query(max_length=100)]) -> str:
    city = city.strip()
    if len(city) < 2 or not any(char.isalpha() for char in city):
        raise HTTPException(400, "Enter a city name with at least two characters.")
    return city


def weather_service(request: Request) -> OpenMeteo:
    return request.app.state.weather_service


City = Annotated[str, Depends(city_name)]
Service = Annotated[OpenMeteo, Depends(weather_service)]


@router.get("/api/info")
def info(request: Request) -> AppInfo:
    return AppInfo(name=request.app.title, version=request.app.version, provider="Open-Meteo")


@router.get("/healthcheck")
def healthcheck() -> Health:
    return Health(status="ok")


@router.get("/weather")
async def weather(city: City, service: Service) -> WeatherResponse:
    return await service.weather(city)


@router.get("/forecast")
async def forecast(city: City, service: Service) -> ForecastResponse:
    return await service.forecast(city)
