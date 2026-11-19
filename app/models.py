from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class WeatherModel(BaseModel):
    model_config = ConfigDict(allow_inf_nan=False)


class Location(WeatherModel):
    name: str
    country: str | None = None
    admin1: str | None = None
    latitude: float
    longitude: float


class Current(WeatherModel):
    time: datetime
    temperature_2m: float
    apparent_temperature: float
    relative_humidity_2m: int
    wind_speed_10m: float
    weather_code: int
    is_day: bool


class ForecastDay(WeatherModel):
    time: date
    temperature_2m_max: float
    temperature_2m_min: float
    precipitation_probability_max: int | None
    weather_code: int


class WeatherResponse(BaseModel):
    location: Location
    current: Current


class ForecastResponse(BaseModel):
    location: Location
    days: list[ForecastDay]


class AppInfo(BaseModel):
    name: str
    version: str
    provider: str


class Health(BaseModel):
    status: str
