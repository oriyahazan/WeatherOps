const form = document.querySelector("#search");
const input = document.querySelector("#city");
const status = document.querySelector("#status");
const error = document.querySelector("#error");
const empty = document.querySelector("#empty");
const results = document.querySelector("#results");
const current = document.querySelector("#current");
const days = document.querySelector("#days");
let activeSearch;

const conditions = [
  [[1, 2], "⛅", "Partly cloudy"],
  [[3], "☁️", "Overcast"],
  [[45, 48], "🌫️", "Fog"],
  [[51, 53, 55], "🌦️", "Drizzle"],
  [[56, 57], "🌧️", "Freezing drizzle"],
  [[61, 63, 65], "🌧️", "Rain"],
  [[66, 67], "🌧️", "Freezing rain"],
  [[71, 73, 75, 77], "❄️", "Snow"],
  [[80, 81, 82], "🌦️", "Rain showers"],
  [[85, 86], "🌨️", "Snow showers"],
  [[95, 96, 99], "⛈️", "Thunderstorms"],
];

function condition(code, isDay = true) {
  if (code === 0) return [isDay ? "☀️" : "🌙", "Clear"];
  const match = conditions.find(([codes]) => codes.includes(code));
  return match ? match.slice(1) : ["🌡️", "Conditions unknown"];
}

function element(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}

function iconNode(icon) {
  const node = element("span", icon, "icon");
  node.setAttribute("aria-hidden", "true");
  return node;
}

const degrees = value => `${Math.round(value)}°`;
const weekday = new Intl.DateTimeFormat(undefined, {
  weekday: "short", month: "short", day: "numeric", timeZone: "UTC",
});

function render(weather, forecast) {
  const { location, current: reading } = weather;
  const [icon, description] = condition(reading.weather_code, reading.is_day);
  const region = [...new Set([location.admin1, location.country])]
    .filter(value => value && value !== location.name).join(", ");
  const temperature = element("div", undefined, "reading");
  temperature.append(iconNode(icon), element("span", degrees(reading.temperature_2m), "temperature"));
  const metrics = element("dl", undefined, "metrics");
  for (const [label, value] of [
    ["Feels like", degrees(reading.apparent_temperature)],
    ["Humidity", `${reading.relative_humidity_2m}%`],
    ["Wind", `${Math.round(reading.wind_speed_10m)} km/h`],
  ]) {
    const metric = element("div");
    metric.append(element("dt", label), element("dd", value));
    metrics.append(metric);
  }
  current.replaceChildren(element("h2", location.name), element("p", region), temperature,
    element("p", description), element("p", `As of ${reading.time.slice(11, 16)} local time`), metrics);

  days.replaceChildren(...forecast.days.map(day => {
    const [symbol, label] = condition(day.weather_code);
    const card = element("li", undefined, "day");
    card.append(
      element("strong", weekday.format(new Date(day.time))),
      iconNode(symbol),
      element("p", label),
      element("p", `High ${degrees(day.temperature_2m_max)} · Low ${degrees(day.temperature_2m_min)}`),
      element("p", day.precipitation_probability_max === null
        ? "Precipitation unavailable" : `${day.precipitation_probability_max}% precipitation`),
    );
    return card;
  }));
}

async function getWeather(path, city, signal) {
  const response = await fetch(`${path}?${new URLSearchParams({ city })}`, { signal });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    return { error: typeof body.detail === "string" ? body.detail : "Weather is unavailable. Please try again." };
  }
  return { data: await response.json() };
}

async function search(city) {
  activeSearch?.abort();
  const controller = new AbortController();
  activeSearch = controller;
  error.hidden = true;
  results.hidden = true;
  empty.hidden = true;
  status.classList.add("loading");
  status.textContent = `Looking up weather for ${city}…`;
  try {
    const [weather, forecast] = await Promise.all([
      getWeather("/weather", city, controller.signal),
      getWeather("/forecast", city, controller.signal),
    ]);
    if (controller.signal.aborted) return;
    const message = weather.error || forecast.error;
    if (message) {
      error.textContent = message;
      error.hidden = false;
      return;
    }
    render(weather.data, forecast.data);
    results.hidden = false;
    status.textContent = `Weather loaded for ${weather.data.location.name}.`;
  } catch {
    if (controller.signal.aborted) return;
    error.textContent = "Could not load weather. Check your connection and try again.";
    error.hidden = false;
  } finally {
    if (activeSearch === controller) {
      status.classList.remove("loading");
      if (results.hidden) status.textContent = "";
    }
  }
}

form.addEventListener("submit", event => {
  event.preventDefault();
  search(input.value.trim());
});
for (const button of document.querySelectorAll("[data-city]")) {
  button.addEventListener("click", () => {
    input.value = button.dataset.city;
    form.requestSubmit();
  });
}
