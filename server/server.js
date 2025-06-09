const express = require("express");
const fetch = require("node-fetch");
const cors = require("cors");
const bodyParser = require("body-parser");
const https = require("https");

const API_KEY = "54cfb51e6f2e98f3f0208cb91f6a1182";
const second_API_KEY = "c90c3db7b6ea99ec7c9e6c6f21fe8a894f25e331";
const PORT = 3000;
const app = express();
app.use(cors());
app.use(bodyParser.json());

// In-memory user store for demo
const users = []; // { username, password, country }
let userScores = {};

const agent = new https.Agent({
  family: 4, // force IPv4
});

app.post("/register", (req, res) => {
  const { username, password, country } = req.body;
  if (!username || !password || !country) {
    return res.status(400).json({ success: false, message: "Missing fields" });
  }
  if (users.find((u) => u.username === username)) {
    return res.status(409).json({ success: false, message: "User exists" });
  }
  users.push({ username, password, country });
  res.json({ success: true });
});

app.post("/login", (req, res) => {
  const { username, password } = req.body;
  const user = users.find(
    (u) => u.username === username && u.password === password
  );
  if (user) {
    res.json({ success: true, country: user.country });
  } else {
    res.status(401).json({ success: false, message: "Invalid credentials" });
  }
});

// Get all countries (for dropdown)
app.get("/countries", async (req, res) => {
  try {
    const response = await fetch(
      "https://countriesnow.space/api/v0.1/countries/positions"
    );
    const data = await response.json();
    const countries = data.data.map((c) => c.name).sort();
    res.json({ countries });
  } catch (err) {
    res.status(500).json({ countries: [], error: "Failed to fetch countries" });
  }
});

// Get cities for a country
app.get("/cities", async (req, res) => {
  const country = req.query.country;
  if (!country) return res.status(400).json({ cities: [] });
  try {
    const response = await fetch(
      "https://countriesnow.space/api/v0.1/countries/cities",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ country }),
      }
    );
    const data = await response.json();
    res.json({ cities: data.data || [] });
  } catch (err) {
    res.status(500).json({ cities: [], error: "Failed to fetch cities" });
  }
});

// Get AQI for a city
app.get("/aqi", async (req, res) => {
  const city = req.query.city;
  if (!city) return res.status(400).json({ error: "City required" });
  // Get coordinates
  const geoUrl = `http://api.openweathermap.org/geo/1.0/direct?q=${encodeURIComponent(
    city
  )}&limit=1&appid=${API_KEY}`;
  const geoResp = await fetch(geoUrl).then((r) => r.json());
  if (!geoResp.length) return res.status(404).json({ error: "City not found" });
  const { lat, lon } = geoResp[0];
  // Get AQI
  const aqiUrl = `http://api.openweathermap.org/data/2.5/air_pollution?lat=${lat}&lon=${lon}&appid=${API_KEY}`;
  const aqiResp = await fetch(aqiUrl).then((r) => r.json());
  let aqi = null;
  try {
    aqi = aqiResp.list[0].main.aqi;
  } catch {
    aqi = null;
  }
  res.json({ aqi });
});

// Get AQI trend for a city (last 5 days)
app.get("/aqi-trend", async (req, res) => {
  const city = req.query.city;
  if (!city) return res.status(400).json({ error: "City required" });
  const geoUrl = `http://api.openweathermap.org/geo/1.0/direct?q=${encodeURIComponent(
    city
  )}&limit=1&appid=${API_KEY}`;
  const geoResp = await fetch(geoUrl).then((r) => r.json());
  if (!geoResp.length) return res.status(404).json({ error: "City not found" });
  const { lat, lon } = geoResp[0];
  const now = Math.floor(Date.now() / 1000);
  const trend = [];
  for (let i = 5; i > 0; i--) {
    const dt = now - i * 24 * 3600;
    const histUrl = `http://api.openweathermap.org/data/2.5/air_pollution/history?lat=${lat}&lon=${lon}&start=${dt}&end=${
      dt + 3600
    }&appid=${API_KEY}`;
    const histResp = await fetch(histUrl).then((r) => r.json());
    let aqi = null;
    try {
      aqi = histResp.list[0].main.aqi;
    } catch {
      aqi = null;
    }
    const date = new Date(dt * 1000).toISOString().slice(0, 10);
    trend.push({ date, aqi });
  }
  res.json({ trend });
});

// Logistic Growth Simulation
app.post("/simulate-growth", (req, res) => {
  const { N0, r, K, days } = req.body;
  let results = [];
  for (let t = 0; t <= days; t++) {
    let N = K / (1 + ((K - N0) / N0) * Math.exp(-r * t));
    results.push({ day: t, value: N });
  }
  res.json({ results });
});

function calculateRegression(data) {
  const n = data.length;
  if (n === 0) return { slope: null, intercept: null };
  const meanX = data.reduce((sum, d) => sum + d.temp, 0) / n;
  const meanY = data.reduce((sum, d) => sum + d.aqi, 0) / n;
  const num = data.reduce(
    (sum, d) => sum + (d.temp - meanX) * (d.aqi - meanY),
    0
  );
  const den = data.reduce((sum, d) => sum + Math.pow(d.temp - meanX, 2), 0);
  const slope = den === 0 ? 0 : num / den;
  const intercept = meanY - slope * meanX;
  return { slope, intercept };
}

app.get("/city-history", async (req, res) => {
  const cityName = req.query.city;
  if (!cityName) return res.status(400).json({ error: "City required" });

  // 1. Get coordinates (for Open-Meteo)
  const geoUrl = `http://api.openweathermap.org/geo/1.0/direct?q=${encodeURIComponent(
    cityName
  )}&limit=1&appid=${API_KEY}`;
  const geoResp = await fetch(geoUrl).then((r) => r.json());
  if (!geoResp.length) return res.status(404).json({ error: "City not found" });
  const { lat, lon } = geoResp[0];

  // 2. Fetch weather forecast from Open-Meteo (next 5 days)
  const weatherUrl = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=temperature_2m_mean&forecast_days=5&timezone=auto`;
  const weatherResp = await fetch(weatherUrl).then((r) => r.json());
  const weatherData = weatherResp.daily;

  // 3. Fetch AQI forecast from WAQI using coordinates
  const aqiUrl = `https://api.waqi.info/feed/geo:${lat};${lon}/?token=${second_API_KEY}`;
  const aqiResp = await fetch(aqiUrl, { agent }).then((r) => r.json());
  let aqiData = [];
  if (
    aqiResp.status === "ok" &&
    aqiResp.data.forecast &&
    aqiResp.data.forecast.daily.pm25
  ) {
    aqiData = aqiResp.data.forecast.daily.pm25.map((d) => ({
      date: d.day,
      aqi: d.avg,
    }));
  }

  // 4. Merge weather and AQI by date (next 5 days)
  let data = [];
  for (let i = 0; i < weatherData.time.length; i++) {
    const date = weatherData.time[i];
    const temp = weatherData.temperature_2m_mean[i];
    const aqiEntry = aqiData.find((a) => a.date === date);
    const aqi = aqiEntry ? aqiEntry.aqi : null;
    data.push({ date, temp, aqi });
  }

  // 5. Filter out entries with missing temp
  data = data.filter((d) => d.temp !== null);

  // Calculate regression
  const regression = calculateRegression(data);
  const message = regressionMessage(
    cityName,
    regression.slope,
    regression.intercept
  );

  res.json({ city: cityName, data, regression, message });
});

function regressionMessage(city, slope) {
  if (slope === null || isNaN(slope)) {
    return `Not enough data to determine the relationship between temperature and AQI in ${city}.`;
  }
  if (Math.abs(slope) < 0.1) {
    return `In ${city}, there is no clear relationship between temperature and AQI over the last 5 days.`;
  }
  if (slope > 0) {
    return `In ${city}, AQI increases by ${slope.toFixed(
      2
    )} for every 1°C rise in temperature (last 5 days).`;
  } else {
    return `In ${city}, AQI decreases by ${Math.abs(slope).toFixed(
      2
    )} for every 1°C rise in temperature (last 5 days).`;
  }
}

app.get("/weather", async (req, res) => {
  const city = req.query.city;
  if (!city) return res.status(400).json({ error: "City required" });
  const geoUrl = `http://api.openweathermap.org/geo/1.0/direct?q=${encodeURIComponent(
    city
  )}&limit=1&appid=${API_KEY}`;
  const geoResp = await fetch(geoUrl).then((r) => r.json());
  if (!geoResp.length) return res.status(404).json({ error: "City not found" });
  const { lat, lon } = geoResp[0];
  const weatherUrl = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${API_KEY}&units=metric`;
  const weatherResp = await fetch(weatherUrl).then((r) => r.json());
  const temp = weatherResp.main.temp;
  const humidity = weatherResp.main.humidity;
  const wind = weatherResp.wind.speed;
  const desc = weatherResp.weather[0].description;

  // Suggestions based on weather
  let suggestions = [];
  if (temp > 30)
    suggestions.push(
      "It's hot! Stay hydrated and avoid strenuous outdoor activities at noon."
    );
  if (temp < 10)
    suggestions.push("It's cold! Dress warmly and limit time outdoors.");
  if (humidity > 80)
    suggestions.push("High humidity. Sensitive groups should take care.");
  if (wind > 8)
    suggestions.push(
      "Windy conditions. Secure loose items and be cautious if cycling or running."
    );
  if (desc.includes("rain"))
    suggestions.push("Rain expected. Carry an umbrella and drive carefully.");
  if (desc.includes("clear"))
    suggestions.push("Clear skies! Great day for outdoor activities.");
  if (suggestions.length === 0)
    suggestions.push("Weather is moderate. Enjoy your day!");

  res.json({ temp, humidity, wind, desc, suggestions });
});

app.post("/eco-action", (req, res) => {
  const { username, action } = req.body;
  if (!username || !action)
    return res.status(400).json({ error: "Missing fields" });
  userScores[username] = (userScores[username] || 0) + 10; // +10 per action
  res.json({ score: userScores[username] });
});

app.get("/eco-score", (req, res) => {
  const username = req.query.username;
  res.json({ score: userScores[username] || 0 });
});

app.get("/eco-challenge", (req, res) => {
  // Rotate challenges weekly, for demo just return one
  res.json({ challenge: "Try a car-free day this week!" });
});

function getPastDates(days) {
  const now = Math.floor(Date.now() / 1000);
  const dates = [];
  for (let i = 0; i < days; i += 3) {
    // every 3 days for 90 days
    dates.push(now - i * 24 * 3600);
  }
  return dates.reverse();
}

app.get("/agri-suitability-city", async (req, res) => {
  const cityName = req.query.city;
  if (!cityName) return res.status(400).json({ error: "City required" });

  // 1. Get coordinates
  const geoUrl = `http://api.openweathermap.org/geo/1.0/direct?q=${encodeURIComponent(
    cityName
  )}&limit=1&appid=${API_KEY}`;
  const geoResp = await fetch(geoUrl).then((r) => r.json());
  if (!geoResp.length) return res.status(404).json({ error: "City not found" });
  const { lat, lon } = geoResp[0];

  // 2. Get weather & AQI for last 3 months (every 3 days)
  const dates = getPastDates(90);
  const weatherSeries = [];
  const aqiSeries = [];
  for (const dt of dates) {
    // Weather (for demo, use current)
    const weatherUrl = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${API_KEY}&units=metric`;
    const weatherResp = await fetch(weatherUrl).then((r) => r.json());
    const temp = weatherResp.main?.temp ?? null;
    const humidity = weatherResp.main?.humidity ?? null;
    weatherSeries.push({ dt, temp, humidity });

    // AQI (use current for demo)
    const aqiUrl = `http://api.openweathermap.org/data/2.5/air_pollution?lat=${lat}&lon=${lon}&appid=${API_KEY}`;
    const aqiResp = await fetch(aqiUrl).then((r) => r.json());
    const aqi = aqiResp.list?.[0]?.main?.aqi ?? null;
    aqiSeries.push({ dt, aqi });
  }

  // 3. Calculate average values
  const avgTemp =
    weatherSeries.reduce((s, x) => s + (x.temp ?? 0), 0) / weatherSeries.length;
  const avgHumidity =
    weatherSeries.reduce((s, x) => s + (x.humidity ?? 0), 0) /
    weatherSeries.length;
  const avgAqi =
    aqiSeries.reduce((s, x) => s + (x.aqi ?? 0), 0) / aqiSeries.length;

  // 4. Ecological model: logistic growth, K factor based on averages
  let f = 1;
  let reason = "Ideal conditions";
  if (avgTemp < 15 || avgTemp > 28) {
    f -= 0.3;
    reason = "Temp not ideal";
  }
  if (avgHumidity < 40 || avgHumidity > 80) {
    f -= 0.3;
    reason = "Humidity not ideal";
  }
  if (avgAqi > 2) {
    f -= 0.3;
    reason = "AQI not ideal";
  }
  if (f < 0.5) reason = "Multiple factors not ideal";

  // Logistic growth simulation for 90 days
  const K0 = 1000;
  const r = 0.1;
  const N0 = 10;
  const K = K0 * f;
  const growthSeries = [];
  for (let t = 0; t <= 90; t += 3) {
    const N = K / (1 + ((K - N0) / N0) * Math.exp(-r * t));
    growthSeries.push({ t, N });
  }

  // Suitability
  let score = "Good";
  if (growthSeries[growthSeries.length - 1].N < 400) score = "Poor";
  else if (growthSeries[growthSeries.length - 1].N < 700) score = "Moderate";

  res.json({
    name: cityName,
    lat,
    lon,
    avgTemp,
    avgHumidity,
    avgAqi,
    score,
    reason,
    weatherSeries,
    aqiSeries,
    growthSeries,
  });
});

app.get("/city-coords", async (req, res) => {
  const city = req.query.city;
  if (!city) return res.status(400).json({ error: "City required" });
  const geoUrl = `http://api.openweathermap.org/geo/1.0/direct?q=${encodeURIComponent(
    city
  )}&limit=1&appid=${API_KEY}`;
  const geoResp = await fetch(geoUrl).then((r) => r.json());
  if (!geoResp.length) return res.status(404).json({ error: "City not found" });
  const { lat, lon } = geoResp[0];
  res.json({ lat, lon });
});

app.post("/simulate-plant", (req, res) => {
  const { plant, temp, humidity, aqi } = req.body;

  let ideal = {
    Wheat: { temp: [15, 25], humidity: [40, 70], aqi: [1, 2] },
    Tomato: { temp: [20, 27], humidity: [50, 70], aqi: [1, 2] },
    Sunflower: { temp: [20, 28], humidity: [30, 60], aqi: [1, 3] },
    Corn: { temp: [18, 27], humidity: [50, 80], aqi: [1, 2] },
    Potato: { temp: [15, 20], humidity: [60, 80], aqi: [1, 2] },
    Rice: { temp: [20, 27], humidity: [70, 90], aqi: [1, 2] },
    Cucumber: { temp: [18, 24], humidity: [60, 80], aqi: [1, 2] },
    Pepper: { temp: [18, 26], humidity: [60, 80], aqi: [1, 2] },
    Lettuce: { temp: [10, 20], humidity: [60, 80], aqi: [1, 2] },
    Carrot: { temp: [16, 22], humidity: [60, 80], aqi: [1, 2] },
    Eggplant: { temp: [20, 30], humidity: [60, 80], aqi: [1, 2] },
  }[plant] || { temp: [15, 28], humidity: [40, 80], aqi: [1, 2] };

  const idealTemp = (ideal.temp[0] + ideal.temp[1]) / 2;
  const idealHumidity = (ideal.humidity[0] + ideal.humidity[1]) / 2;
  const idealAqi = (ideal.aqi[0] + ideal.aqi[1]) / 2;
  let f = 1;
  let reasons = [];
  if (temp < ideal.temp[0] || temp > ideal.temp[1]) {
    f -= gaussianPenalty(temp, idealTemp, 5, 0.3);
    reasons.push("Temperature not ideal");
  }
  if (humidity < ideal.humidity[0] || humidity > ideal.humidity[1]) {
    f -= gaussianPenalty(humidity, idealHumidity, 10, 0.3);
    reasons.push("Humidity not ideal");
  }
  if (aqi < ideal.aqi[0] || aqi > ideal.aqi[1]) {
    f -= gaussianPenalty(aqi, idealAqi, 1, 0.3);
    reasons.push("Air quality not ideal");
  }
  if (f < 0)
    reasons = [
      "Temperature not ideal\nHumidity not ideal\nAir quality not ideal",
    ];

  const cropParams = {
    Wheat: { K0: 1000, thriving: 800, struggling: 400, r: 0.1, N0: 10 },
    Tomato: { K0: 1000, thriving: 800, struggling: 400, r: 0.12, N0: 10 },
    Sunflower: { K0: 1000, thriving: 800, struggling: 400, r: 0.09, N0: 10 },
    Corn: {
      K0: 1000,
      thriving: 800,
      struggling: 400,
      r: 0.11,
      N0: 10,
    },
    Potato: {
      K0: 1000,
      thriving: 800,
      struggling: 400,
      r: 0.1,
      N0: 10,
    },
    Rice: {
      K0: 1000,
      thriving: 800,
      struggling: 400,
      r: 0.12,
      N0: 10,
    },
    Cucumber: {
      K0: 1000,
      thriving: 800,
      struggling: 400,
      r: 0.13,
      N0: 10,
    },
    Pepper: {
      K0: 1000,
      thriving: 800,
      struggling: 400,
      r: 0.12,
      N0: 10,
    },
    Lettuce: {
      K0: 1000,
      thriving: 800,
      struggling: 400,
      r: 0.09,
      N0: 10,
    },
    Carrot: {
      K0: 1000,
      thriving: 800,
      struggling: 400,
      r: 0.1,
      N0: 10,
    },
    Eggplant: {
      K0: 1000,
      thriving: 800,
      struggling: 400,
      r: 0.11,
      N0: 10,
    },
  };

  // Dynamically select parameters for the chosen plant
  const params = cropParams[plant] || cropParams["Wheat"];
  const { K0, thriving, struggling, r, N0 } = params;

  const K = K0 * f;
  const growthSeries = [];
  for (let t = 0; t <= 90; t += 3) {
    const N = K / (1 + ((K - N0) / N0) * Math.exp(-r * t));
    growthSeries.push({ t, N });
  }

  let result = "Your plant is thriving!";
  if (growthSeries[growthSeries.length - 1].N < struggling)
    result = "Your plant died!";
  else if (growthSeries[growthSeries.length - 1].N < thriving)
    result = "Your plant is struggling.";

  // Return the result as before
  res.json({
    plant,
    temp,
    humidity,
    aqi,
    growthSeries,
    result,
    reasons,
    thriving,
    ideal,
  });
});

function gaussianPenalty(val, ideal, sigma = 5, maxPenalty = 0.3) {
  // val: the actual value (e.g., temp)
  // ideal: the optimal value (e.g., 22 for temp)
  // sigma: how quickly penalty increases as you move away from ideal
  // maxPenalty: the maximum penalty for extreme deviation
  return (
    maxPenalty *
    (1 - Math.exp(-Math.pow(val - ideal, 2) / (2 * Math.pow(sigma, 2))))
  );
}

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send("Something went wrong!");
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
