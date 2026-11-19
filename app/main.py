from contextlib import asynccontextmanager
from pathlib import Path

import httpx
from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from .open_meteo import OpenMeteo, Settings
from .routes import router

static = Path(__file__).parent / "static"


def create_app(*, transport: httpx.AsyncBaseTransport | None = None) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        settings = Settings.from_env()
        async with httpx.AsyncClient(timeout=settings.timeout, transport=transport) as client:
            app.state.weather_service = OpenMeteo(client, settings)
            yield

    app = FastAPI(title="WeatherOps", version="1.0.0", lifespan=lifespan)
    app.include_router(router)
    app.mount("/static", StaticFiles(directory=static), name="static")

    @app.get("/", include_in_schema=False)
    def dashboard():
        return FileResponse(static / "index.html")

    return app


app = create_app()
