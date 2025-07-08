const express = require("express");
const fetch = require("node-fetch");
const cors = require("cors");
const bodyParser = require("body-parser");
const https = require("https");
const fs = require("fs");
const csv = require("csv-parser");
const { GoogleGenAI } = require("@google/genai");

const API_KEY = "54cfb51e6f2e98f3f0208cb91f6a1182";
const second_API_KEY = "c90c3db7b6ea99ec7c9e6c6f21fe8a894f25e331";
const PORT = 3000;

// Initialize Google Gemini AI (Free tier: 15 req/min, 1,500 req/day)
// Get your free API key from: https://ai.google.dev/
const GEMINI_API_KEY = "AIzaSyDS7FaSpsQt1SUbF_T5MwcB44x99XFS38M";
const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY });
const app = express();
app.use(cors());
app.use(bodyParser.json());

// In-memory user store for demo
const users = []; // { username, password, country }

const agent = new https.Agent({
  family: 4, // force IPv4
});

// In-memory user data
const challenges = [
  "Try a car-free day this week!",
  "Reduce your plastic use for a day!",
  "Take a 5-minute shorter shower!",
  "Plant something in your garden or a pot!",
];

const badgeLevels = [
  { name: "Eco Newbie", points: 0 },
  { name: "Green Starter", points: 10, prize: null },
  { name: "Eco Hero", points: 25, prize: "10% off at GreenStore" },
  { name: "Planet Protector", points: 50, prize: "Free Eco Tote Bag" },
  {
    name: "Earth Guardian",
    points: 100,
    prize: "Eco-Friendly Water Bottle",
  },
  {
    name: "Climate Champion",
    points: 200,
    prize: "Certificate of Eco Excellence",
  },
  {
    name: "Sustainability Legend",
    points: 300,
    prize: "Tree planted in your name",
  },
];

// Helper to get user or create if not exists
function getUser(username) {
  if (!users[username]) {
    users[username] = {
      score: 0,
      actions: [],
    };
  }
  return users[username];
}

// GET /eco-score?username=...
app.get("/api/eco-score", (req, res) => {
  const { username } = req.query;
  const user = getUser(username);
  res.json({ score: user.score });
});

// GET /eco-challenge
app.get("/api/eco-challenge", (req, res) => {
  // Random challenge each time
  const challenge = challenges[Math.floor(Math.random() * challenges.length)];
  res.json({ challenge });
});

// POST /eco-action
app.post("/api/eco-action", (req, res) => {
  const { username, action } = req.body;
  const user = getUser(username);

  // Simple scoring
  let points = 0;
  if (action === "biked") points = 5;
  if (action === "planted_tree") points = 10;

  user.score += points;
  user.actions.push({ action, date: new Date() });

  res.json({ success: true, newScore: user.score });
});

app.get("/api/eco-rewards", (req, res) => {
  const { username } = req.query;
  const user = getUser(username);

  // Find badges earned
  const badges = badgeLevels
    .filter((b) => user.score >= b.points)
    .map((b) => b.name);

  // Find prizes earned
  const prizes = badgeLevels
    .filter((b) => user.score >= b.points && b.prize)
    .map((b) => b.prize);

  // Next badge info
  const next = badgeLevels.find((b) => user.score < b.points);
  const nextBadge = next ? next.name : "All badges unlocked!";
  const pointsToNextBadge = next ? next.points - user.score : 0;
  const nextPrize = next && next.prize ? next.prize : null;

  res.json({
    badges,
    prizes,
    nextBadge,
    pointsToNextBadge,
    nextPrize,
  });
});

// GET /eco-impact?username=...
app.get("/api/eco-impact", (req, res) => {
  const { username } = req.query;
  const user = getUser(username);

  // Simple impact calculation
  // 1 point = 0.5kg CO2 saved
  const co2Saved = (user.score * 0.5).toFixed(1);

  res.json({
    impact: `You've saved approximately ${co2Saved} kg of CO₂!`,
  });
});

app.post("/api/register", (req, res) => {
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

app.post("/api/login", (req, res) => {
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
app.get("/api/countries", async (req, res) => {
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
app.get("/api/cities", async (req, res) => {
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
app.get("/api/aqi", async (req, res) => {
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
app.get("/api/aqi-trend", async (req, res) => {
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
app.post("/api/simulate-growth", (req, res) => {
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

app.get("/api/city-history", async (req, res) => {
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

app.get("/api/weather", async (req, res) => {
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

function getPastDates(days) {
  const now = Math.floor(Date.now() / 1000);
  const dates = [];
  for (let i = 0; i < days; i += 3) {
    // every 3 days for 90 days
    dates.push(now - i * 24 * 3600);
  }
  return dates.reverse();
}

function getPlantRecommendation(plantName) {
  return new Promise((resolve, reject) => {
    const results = [];
    fs.createReadStream("Plants_Recommended_For_Planting.csv")
      .pipe(csv())
      .on("data", (data) => results.push(data))
      .on("end", () => {
        const plant = results.find(
          (row) => row.Crop.toLowerCase() === plantName.toLowerCase()
        );
        if (!plant) return resolve(null);
        
        // Parse all the comprehensive agricultural data
        const plantData = {
          // Environmental requirements
          minTemp: Number(plant["Min Temperature (°C)"]),
          maxTemp: Number(plant["Max Temperature (°C)"]),
          minAqi: Number(plant["Min AQI"]),
          maxAqi: Number(plant["Max AQI"]),
          minHumidity: Number(plant["Min Humidity (%)"]),
          maxHumidity: Number(plant["Max Humidity (%)"]),
          
          // Soil requirements
          minSoilPH: Number(plant["Min Soil pH"]),
          maxSoilPH: Number(plant["Max Soil pH"]),
          soilTypes: plant["Soil Type"].split(";"),
          
          // Agricultural timing
          daysToMaturity: Number(plant["Days to Maturity"]),
          plantingSeasons: plant["Planting Seasons"].split(";"),
          harvestWindow: Number(plant["Harvest Window (days)"]),
          storageLife: Number(plant["Storage Life (days)"]),
          
          // Economic data
          seedCostPerHectare: Number(plant["Seed Cost per Hectare (USD)"]),
          expectedYieldPerHectare: Number(plant["Expected Yield per Hectare (kg)"]),
          marketPricePerKg: Number(plant["Market Price per kg (USD)"]),
          marketDemand: plant["Market Demand"],
          
          // Physical planting requirements
          spacing: Number(plant["Spacing (cm)"]),
          plantingDepth: Number(plant["Planting Depth (cm)"]),
          waterRequirements: Number(plant["Water Requirements (mm)"]),
          
          // Nutrient requirements
          nitrogenNeeds: plant["Nitrogen Needs"],
          phosphorusNeeds: plant["Phosphorus Needs"],
          potassiumNeeds: plant["Potassium Needs"],
          
          // Disease and pest information
          commonDiseases: [
            plant["Common Disease 1"],
            plant["Common Disease 2"],
            plant["Common Disease 3"]
          ].filter(d => d && d.trim()),
          
          // Companion planting
          companionPlants: [
            plant["Companion Plant 1"],
            plant["Companion Plant 2"],
            plant["Companion Plant 3"]
          ].filter(p => p && p.trim()),
          
          // Classification
          category: plant["Category"]
        };

        resolve(plantData);
      })
      .on("error", reject);
  });
}

app.get("/api/agri-suitability-city", async (req, res) => {
  const cityName = req.query.city;
  const plantName = req.query.plant;
  const soilType = req.query.soilType || "loamy"; // Default to loamy if not provided
  const soilPH = parseFloat(req.query.soilPH) || 6.5; // Default to 6.5 if not provided
  
  if (!cityName || !plantName)
    return res.status(400).json({ error: "City and plant required" });

  // 1. Get comprehensive plant data from CSV
  const plantProfile = await getPlantRecommendation(plantName);
  if (!plantProfile)
    return res.status(404).json({ error: "Plant not found in CSV" });

  // 2. Get coordinates
  const geoUrl = `http://api.openweathermap.org/geo/1.0/direct?q=${encodeURIComponent(
    cityName
  )}&limit=1&appid=${API_KEY}`;
  const geoResp = await fetch(geoUrl).then((r) => r.json());
  if (!geoResp.length) return res.status(404).json({ error: "City not found" });
  const { lat, lon } = geoResp[0];

  // 3. Get weather & AQI for last 3 months (every 3 days)
  const dates = getPastDates(90);

  // 4. Fetch weather and AQI in parallel
  const weatherPromises = dates.map((dt) =>
    fetch(
      `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${API_KEY}&units=metric`
    )
      .then((r) => r.json())
      .then((weatherResp) => ({
        dt,
        temp: weatherResp.main?.temp ?? null,
        humidity: weatherResp.main?.humidity ?? null,
      }))
      .catch(() => ({ dt, temp: null, humidity: null }))
  );

  const aqiPromises = dates.map((dt) =>
    fetch(
      `http://api.openweathermap.org/data/2.5/air_pollution?lat=${lat}&lon=${lon}&appid=${API_KEY}`
    )
      .then((r) => r.json())
      .then((aqiResp) => {
        let aqiValue = null;
        if (aqiResp.list?.[0]?.main?.aqi) {
          const aqiMap = { 1: 0, 2: 51, 3: 101, 4: 151, 5: 201 };
          aqiValue = aqiMap[aqiResp.list[0].main.aqi];
        }
        return { dt, aqi: aqiValue };
      })
      .catch(() => ({ dt, aqi: null }))
  );

  const [weatherSeries, aqiSeries] = await Promise.all([
    Promise.all(weatherPromises),
    Promise.all(aqiPromises),
  ]);

  // 5. Calculate average environmental values
  const avgTemp =
    weatherSeries.reduce((s, x) => s + (x.temp ?? 0), 0) / weatherSeries.length;
  const avgHumidity =
    weatherSeries.reduce((s, x) => s + (x.humidity ?? 0), 0) /
    weatherSeries.length;
  const avgAqi =
    aqiSeries.reduce((s, x) => s + (x.aqi ?? 0), 0) / aqiSeries.length;

  // 6. COMPREHENSIVE SUITABILITY ANALYSIS using all CSV data
  
  // Environmental suitability
  const tempSuitability = avgTemp >= plantProfile.minTemp && avgTemp <= plantProfile.maxTemp;
  const humiditySuitability = avgHumidity >= plantProfile.minHumidity && avgHumidity <= plantProfile.maxHumidity;
  const aqiSuitability = avgAqi >= plantProfile.minAqi && avgAqi <= plantProfile.maxAqi;
  
  // Calculate environmental stress factor
  const environmentalFactor = calculateEnvironmentalFactor(
    avgTemp, avgHumidity, avgAqi,
    [plantProfile.minTemp, plantProfile.maxTemp],
    [plantProfile.minHumidity, plantProfile.maxHumidity],
    [plantProfile.minAqi, plantProfile.maxAqi]
  );

     // 7. SOIL ANALYSIS (using user-provided soil data)
   const soilSuitability = plantProfile.soilTypes.includes(soilType);
   const pHSuitability = soilPH >= plantProfile.minSoilPH && soilPH <= plantProfile.maxSoilPH;
  
  // 8. SEASONAL ANALYSIS
  const currentMonth = new Date().getMonth() + 1;
  const seasonalSuitability = assessSeasonalSuitability(plantProfile, getCurrentSeason(currentMonth));
  
     // 9. DISEASE RISK ASSESSMENT
   const diseaseRisk = assessDiseaseRisk(avgTemp, avgHumidity, soilType, plantProfile);
   const weatherRisk = assessWeatherRisk(avgTemp, avgHumidity, plantProfile);
   
   // 10. ECONOMIC VIABILITY ANALYSIS
   const estimatedFarmSize = 1.0; // Default 1 hectare for city analysis
   const estimatedBudget = 10000; // Default budget for analysis
   
   // Calculate costs with environmental adjustments
   const irrigationPlan = generateIrrigationPlan(plantProfile, avgTemp, avgHumidity, estimatedFarmSize);
   const fertilizationPlan = generateFertilizationPlan(plantProfile, soilType);
  
  const baseCosts = {
    seeds: plantProfile.seedCostPerHectare * estimatedFarmSize,
    irrigation: irrigationPlan.cost,
    fertilization: fertilizationPlan.cost,
    labor: 800 * estimatedFarmSize,
    equipment: 300 * estimatedFarmSize,
    pestControl: 150 * estimatedFarmSize,
    miscellaneous: 100 * estimatedFarmSize
  };
  
  // Apply environmental stress cost multipliers
  const stressCostMultiplier = 1 + (1 - environmentalFactor) * 0.5; // Up to 50% cost increase
  const totalCosts = Object.values(baseCosts).reduce((sum, cost) => sum + cost, 0) * stressCostMultiplier;
  
  // Calculate yield with environmental adjustments
  const baseYield = plantProfile.expectedYieldPerHectare * estimatedFarmSize;
  const adjustedYield = baseYield * environmentalFactor * (soilSuitability ? 1.0 : 0.8) * (seasonalSuitability.factor || 0.9);
  
  // Economic calculations
  const grossRevenue = adjustedYield * plantProfile.marketPricePerKg;
  const netProfit = grossRevenue - totalCosts;
  const profitMargin = grossRevenue > 0 ? (netProfit / grossRevenue) * 100 : 0;
  const roi = totalCosts > 0 ? (netProfit / totalCosts) * 100 : 0;
  
  // 11. OVERALL SCORE CALCULATION
  const overallScore = calculateFarmingScore({
    tempSuitability,
    humiditySuitability,
    aqiSuitability,
    pHSuitability,
    soilTypeSuitability: soilSuitability,
    budgetSufficient: estimatedBudget >= totalCosts,
    diseaseRisk,
    marketDemand: plantProfile.marketDemand,
    seasonalSuitability: seasonalSuitability
  });
  
  // Determine suitability category
  let suitabilityCategory = "poor";
  let suitabilityReason = "Multiple environmental factors unsuitable";
  
  if (overallScore >= 85) {
    suitabilityCategory = "excellent";
    suitabilityReason = "Ideal conditions for cultivation";
  } else if (overallScore >= 70) {
    suitabilityCategory = "good";
    suitabilityReason = "Good conditions with minor challenges";
  } else if (overallScore >= 55) {
    suitabilityCategory = "moderate";
    suitabilityReason = "Moderate conditions requiring management";
  } else if (overallScore >= 40) {
    suitabilityCategory = "challenging";
    suitabilityReason = "Challenging conditions, high risk";
  }
  
  // 12. COMPREHENSIVE RESPONSE
  res.json({
    // Basic information
    name: cityName,
    lat,
    lon,
    plant: plantName,
    
    // Environmental data
    avgTemp: Math.round(avgTemp * 10) / 10,
    avgHumidity: Math.round(avgHumidity * 10) / 10,
    avgAqi: Math.round(avgAqi),
    
    // Suitability analysis
    score: suitabilityCategory,
    overallScore: Math.round(overallScore),
    reason: suitabilityReason,
    
    // Detailed assessments
    environmental: {
      temperature: { suitable: tempSuitability, value: avgTemp, optimal: [plantProfile.minTemp, plantProfile.maxTemp] },
      humidity: { suitable: humiditySuitability, value: avgHumidity, optimal: [plantProfile.minHumidity, plantProfile.maxHumidity] },
      airQuality: { suitable: aqiSuitability, value: avgAqi, optimal: [plantProfile.minAqi, plantProfile.maxAqi] },
      factor: Math.round(environmentalFactor * 100) / 100
    },
    
         soil: {
       type: soilType,
       pH: soilPH,
       suitable: soilSuitability && pHSuitability,
       optimalTypes: plantProfile.soilTypes,
       optimalPH: [plantProfile.minSoilPH, plantProfile.maxSoilPH]
     },
    
    seasonal: {
      suitable: seasonalSuitability.suitable,
      factor: seasonalSuitability.factor,
      bestSeasons: plantProfile.plantingSeasons,
      currentSeason: getCurrentSeason(currentMonth)
    },
    
    risks: {
      disease: diseaseRisk,
      weather: weatherRisk,
      commonDiseases: plantProfile.commonDiseases
    },
    
    economics: {
      estimatedYield: Math.round(adjustedYield),
      totalCosts: Math.round(totalCosts),
      grossRevenue: Math.round(grossRevenue),
      netProfit: Math.round(netProfit),
      profitMargin: Math.round(profitMargin * 10) / 10,
      roi: Math.round(roi * 10) / 10,
      breakEven: totalCosts > 0 ? Math.round(totalCosts / plantProfile.marketPricePerKg) : 0
    },
    
    farming: {
      plantingWindow: plantProfile.plantingSeasons,
      daysToMaturity: plantProfile.daysToMaturity,
      harvestWindow: plantProfile.harvestWindow,
      waterRequirements: plantProfile.waterRequirements,
      companionPlants: plantProfile.companionPlants
    },
    
    // Raw data for analysis
    weatherSeries: weatherSeries.slice(0, 10), // Limit data for response size
    aqiSeries: aqiSeries.slice(0, 10)
  });
});

// Helper function to get current season based on month
function getCurrentSeason(month) {
  if (month >= 3 && month <= 5) return "Spring";
  if (month >= 6 && month <= 8) return "Summer";
  if (month >= 9 && month <= 11) return "Fall";
  return "Winter";
}

app.get("/api/city-coords", async (req, res) => {
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

app.get("/api/plant-names", (req, res) => {
  const results = [];
  fs.createReadStream("Plants_Recommended_For_Planting.csv")
    .pipe(csv())
    .on("data", (data) => {
      if (data.Crop) results.push(data.Crop);
    })
    .on("end", () => {
      res.json({ plants: results });
    })
    .on("error", (err) => {
      res.status(500).json({ error: "Failed to read CSV file." });
    });
});

app.get("/api/agri-suitability-cities", async (req, res) => {
  const plant = req.query.plant;
  const country = req.query.country;
  const soilType = req.query.soilType || "loamy";
  const soilPH = req.query.soilPH || "6.5";
  
  if (!plant) return res.status(400).json({ error: "Plant required" });

  // 1. Get all cities for the country
  // You can use your existing /cities endpoint logic here
  let cities = [];
  if (country) {
    // Fetch cities for the country
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
      cities = data.data || [];
    } catch (err) {
      return res.status(500).json({ error: "Failed to fetch cities" });
    }
  } else {
    // If no country provided, you can return a default list or error
    return res.status(400).json({ error: "Country required" });
  }

  // 2. For each city, get coordinates and suitability
  const results = [];
  for (const city of cities) {
    try {
      // Call your agri-suitability-city endpoint for each city
      const suitabilityResp = await fetch(
        `http://192.168.0.180:3000/agri-suitability-city?city=${encodeURIComponent(
          city
        )}&plant=${encodeURIComponent(plant)}&soilType=${encodeURIComponent(soilType)}&soilPH=${soilPH}`
      );
      if (suitabilityResp.status === 200) {
        const suitabilityData = await suitabilityResp.json();
        results.push({
          name: city,
          lat: suitabilityData.lat,
          lon: suitabilityData.lon,
          suitability: suitabilityData.score.toLowerCase(), // allows: "good", "moderate", "poor"
        });
      }
    } catch (err) {
      // Skip city if error occurs
    }
  }
  console.log(results);

  res.json({ cities: results });
});

// Add comprehensive vegetable database for real farming applications
const comprehensiveVegetableDatabase = {
  // LEAFY GREENS
  "Lettuce": {
    category: "Leafy Greens",
    variety: "Iceberg/Romaine/Butterhead",
    // Environmental requirements
    temp: [10, 20], humidity: [60, 80], aqi: [1, 2],
    
    // Soil requirements (crucial for farmers)
    soilPH: [6.0, 7.0], // optimal pH range
    soilType: ["loamy", "sandy-loam"], // preferred soil types
    nitrogenNeeds: "medium", // low/medium/high
    phosphorusNeeds: "medium",
    potassiumNeeds: "high",
    organicMatter: "15-20%", // required organic matter
    drainageNeeds: "well-drained",
    
    // Economic factors
    seedCostPerHectare: 200, // USD
    expectedYieldPerHectare: 25000, // kg
    averageMarketPrice: 2.5, // USD per kg
    profitMargin: 0.65, // 65% profit margin
    
    // Seasonal planning
    plantingSeasons: ["Early Spring", "Fall"],
    daysToMaturity: 65,
    harvestWindow: 10, // days
    plantingDepth: 0.5, // cm
    spacing: 20, // cm between plants
    
    // Water management
    waterRequirements: 350, // mm per season
    irrigationFrequency: "every 2-3 days",
    
    // Companion planting (ecosystem benefits)
    companionPlants: ["Carrots", "Radishes", "Onions"],
    avoidPlants: ["Cabbage", "Broccoli"],
    
    // Disease/Pest risks
    commonDiseases: ["Downy Mildew", "Aphids", "Slugs"],
    diseaseRiskFactors: ["High humidity + cool temp", "Poor drainage"],
    
    // Practical farming tips
    harvesting: "Cut outer leaves first, allow center to continue growing",
    storage: "Refrigerate immediately, lasts 7-10 days",
    marketDemand: "High year-round"
  },

  "Spinach": {
    category: "Leafy Greens",
    variety: "Baby/Mature leaf",
    temp: [8, 18], humidity: [50, 80], aqi: [1, 2],
    
    soilPH: [6.0, 7.5], soilType: ["loamy", "clay-loam"],
    nitrogenNeeds: "high", phosphorusNeeds: "medium", potassiumNeeds: "high",
    organicMatter: "20-25%", drainageNeeds: "well-drained",
    
    seedCostPerHectare: 180, expectedYieldPerHectare: 20000,
    averageMarketPrice: 3.0, profitMargin: 0.70,
    
    plantingSeasons: ["Early Spring", "Fall", "Winter"],
    daysToMaturity: 45, harvestWindow: 7,
    plantingDepth: 1.0, spacing: 15,
    
    waterRequirements: 300, irrigationFrequency: "every 2 days",
    
    companionPlants: ["Tomatoes", "Carrots", "Radishes"],
    avoidPlants: ["Fennel"],
    
    commonDiseases: ["Leaf Spot", "Aphids", "Leaf Miners"],
    diseaseRiskFactors: ["Wet leaves", "Overcrowding"],
    
    harvesting: "Cut entire plant or harvest outer leaves",
    storage: "Refrigerate, lasts 5-7 days",
    marketDemand: "Very High"
  },

  // ROOT VEGETABLES
  "Carrot": {
    category: "Root Vegetables", 
    variety: "Orange/Purple/White varieties",
    temp: [16, 22], humidity: [60, 80], aqi: [1, 2],
    
    soilPH: [6.0, 6.8], soilType: ["sandy-loam", "sandy"],
    nitrogenNeeds: "low", phosphorusNeeds: "high", potassiumNeeds: "high",
    organicMatter: "10-15%", drainageNeeds: "excellent-drainage",
    
    seedCostPerHectare: 150, expectedYieldPerHectare: 35000,
    averageMarketPrice: 1.8, profitMargin: 0.60,
    
    plantingSeasons: ["Spring", "Summer"],
    daysToMaturity: 75, harvestWindow: 14,
    plantingDepth: 1.0, spacing: 5,
    
    waterRequirements: 400, irrigationFrequency: "every 3-4 days",
    
    companionPlants: ["Lettuce", "Onions", "Tomatoes"],
    avoidPlants: ["Dill", "Parsnips"],
    
    commonDiseases: ["Carrot Fly", "Root Rot", "Cavity Spot"],
    diseaseRiskFactors: ["Heavy clay soil", "Overwatering"],
    
    harvesting: "Pull when shoulders are 3/4 inch diameter",
    storage: "Cool, humid conditions, lasts 2-4 months",
    marketDemand: "High"
  },

  "Potato": {
    category: "Root Vegetables",
    variety: "Russet/Red/Fingerling",
    temp: [15, 20], humidity: [60, 80], aqi: [1, 2],
    
    soilPH: [5.0, 6.5], soilType: ["sandy-loam", "loamy"],
    nitrogenNeeds: "medium", phosphorusNeeds: "high", potassiumNeeds: "very-high",
    organicMatter: "15-20%", drainageNeeds: "well-drained",
    
    seedCostPerHectare: 800, expectedYieldPerHectare: 45000,
    averageMarketPrice: 1.2, profitMargin: 0.55,
    
    plantingSeasons: ["Early Spring"],
    daysToMaturity: 90, harvestWindow: 21,
    plantingDepth: 10.0, spacing: 30,
    
    waterRequirements: 500, irrigationFrequency: "deep watering weekly",
    
    companionPlants: ["Beans", "Corn", "Peas"],
    avoidPlants: ["Tomatoes", "Eggplant", "Peppers"],
    
    commonDiseases: ["Late Blight", "Scab", "Colorado Potato Beetle"],
    diseaseRiskFactors: ["Wet conditions", "Nightshade family nearby"],
    
    harvesting: "Dig when foliage dies back, cure in sun 1-2 hours",
    storage: "Cool, dark, dry place, lasts 2-6 months",
    marketDemand: "Very High"
  },

  // FRUITING VEGETABLES  
  "Tomato": {
    category: "Fruiting Vegetables",
    variety: "Determinate/Indeterminate/Cherry",
    temp: [20, 27], humidity: [50, 70], aqi: [1, 2],
    
    soilPH: [6.0, 6.8], soilType: ["loamy", "sandy-loam"],
    nitrogenNeeds: "medium", phosphorusNeeds: "high", potassiumNeeds: "very-high",
    organicMatter: "20-25%", drainageNeeds: "well-drained",
    
    seedCostPerHectare: 300, expectedYieldPerHectare: 60000,
    averageMarketPrice: 3.5, profitMargin: 0.75,
    
    plantingSeasons: ["Late Spring"],
    daysToMaturity: 80, harvestWindow: 30,
    plantingDepth: 0.5, spacing: 45,
    
    waterRequirements: 600, irrigationFrequency: "consistent daily",
    
    companionPlants: ["Basil", "Peppers", "Spinach"],
    avoidPlants: ["Potato", "Fennel", "Walnut trees"],
    
    commonDiseases: ["Blight", "Hornworms", "Cracking"],
    diseaseRiskFactors: ["Inconsistent watering", "High humidity"],
    
    harvesting: "Pick when color changes but still firm",
    storage: "Room temperature to ripen, then refrigerate",
    marketDemand: "Very High"
  },

  "Cucumber": {
    category: "Fruiting Vegetables",
    variety: "Slicing/Pickling/English",
    temp: [18, 24], humidity: [60, 80], aqi: [1, 2],
    
    soilPH: [6.0, 7.0], soilType: ["loamy", "sandy-loam"],
    nitrogenNeeds: "medium", phosphorusNeeds: "medium", potassiumNeeds: "high",
    organicMatter: "15-20%", drainageNeeds: "well-drained",
    
    seedCostPerHectare: 250, expectedYieldPerHectare: 40000,
    averageMarketPrice: 2.0, profitMargin: 0.65,
    
    plantingSeasons: ["Late Spring", "Early Summer"],
    daysToMaturity: 55, harvestWindow: 21,
    plantingDepth: 2.0, spacing: 30,
    
    waterRequirements: 450, irrigationFrequency: "every 2 days",
    
    companionPlants: ["Radishes", "Beans", "Corn"],
    avoidPlants: ["Aromatic herbs", "Melons"],
    
    commonDiseases: ["Cucumber Beetle", "Powdery Mildew", "Bacterial Wilt"],
    diseaseRiskFactors: ["Poor air circulation", "Overhead watering"],
    
    harvesting: "Pick when 6-8 inches long, harvest daily during peak",
    storage: "Refrigerate, lasts 7-10 days",
    marketDemand: "High"
  },

  "Pepper": {
    category: "Fruiting Vegetables",
    variety: "Bell/Hot/Sweet",
    temp: [18, 26], humidity: [60, 80], aqi: [1, 2],
    
    soilPH: [6.0, 7.0], soilType: ["loamy", "sandy-loam"],
    nitrogenNeeds: "medium", phosphorusNeeds: "high", potassiumNeeds: "high",
    organicMatter: "18-22%", drainageNeeds: "well-drained",
    
    seedCostPerHectare: 400, expectedYieldPerHectare: 35000,
    averageMarketPrice: 4.0, profitMargin: 0.70,
    
    plantingSeasons: ["Late Spring"],
    daysToMaturity: 70, harvestWindow: 28,
    plantingDepth: 0.5, spacing: 40,
    
    waterRequirements: 500, irrigationFrequency: "deep watering 2x/week",
    
    companionPlants: ["Tomatoes", "Basil", "Onions"],
    avoidPlants: ["Beans", "Fennel"],
    
    commonDiseases: ["Pepper Maggot", "Anthracnose", "Bacterial Spot"],
    diseaseRiskFactors: ["Cool wet weather", "Poor drainage"],
    
    harvesting: "Pick when full size and firm, can harvest green or colored",
    storage: "Refrigerate, lasts 1-2 weeks",
    marketDemand: "Very High"
  },

  "Eggplant": {
    category: "Fruiting Vegetables",
    variety: "Globe/Asian/Italian",
    temp: [20, 30], humidity: [60, 80], aqi: [1, 2],
    
    soilPH: [5.5, 7.0], soilType: ["loamy", "sandy-loam"],
    nitrogenNeeds: "high", phosphorusNeeds: "medium", potassiumNeeds: "high",
    organicMatter: "20-25%", drainageNeeds: "well-drained",
    
    seedCostPerHectare: 350, expectedYieldPerHectare: 30000,
    averageMarketPrice: 3.0, profitMargin: 0.65,
    
    plantingSeasons: ["Late Spring"],
    daysToMaturity: 85, harvestWindow: 35,
    plantingDepth: 0.5, spacing: 50,
    
    waterRequirements: 550, irrigationFrequency: "consistent moisture",
    
    companionPlants: ["Tomatoes", "Peppers", "Marigolds"],
    avoidPlants: ["Potato", "Fennel"],
    
    commonDiseases: ["Flea Beetles", "Verticillium Wilt", "Spider Mites"],
    diseaseRiskFactors: ["Cool temperatures", "Stress conditions"],
    
    harvesting: "Pick when skin is glossy and firm, before seeds harden",
    storage: "Use within few days, doesn't store well",
    marketDemand: "Medium-High"
  }
};

// Function to get comprehensive vegetable recommendation
function getComprehensiveVegetableData(vegetableName) {
  const vegData = comprehensiveVegetableDatabase[vegetableName];
  if (!vegData) return null;
  return vegData;
}

// Enhanced farmer recommendation endpoint with soil and economic analysis
app.post("/api/farmer-recommendation", async (req, res) => {
  const { 
    vegetable, 
    city, 
    soilPH = 6.5, 
    soilType = "loamy", 
    farmSize = 1, // hectares
    budget = 10000 // USD
  } = req.body;

  if (!vegetable || !city) {
    return res.status(400).json({ error: "Vegetable and city required" });
  }

  try {
    // 1. Get vegetable data
    const vegData = getComprehensiveVegetableData(vegetable);
    if (!vegData) {
      return res.status(404).json({ error: "Vegetable not found in database" });
    }

    // 2. Get current weather conditions
    const geoUrl = `http://api.openweathermap.org/geo/1.0/direct?q=${encodeURIComponent(city)}&limit=1&appid=${API_KEY}`;
    const geoResp = await fetch(geoUrl).then(r => r.json());
    if (!geoResp.length) {
      return res.status(404).json({ error: "City not found" });
    }

    const { lat, lon } = geoResp[0];
    const weatherUrl = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${API_KEY}&units=metric`;
    const weatherResp = await fetch(weatherUrl).then(r => r.json());
    
    const currentTemp = weatherResp.main?.temp || 20;
    const currentHumidity = weatherResp.main?.humidity || 60;

    // 3. Environmental suitability analysis
    const tempSuitability = currentTemp >= vegData.temp[0] && currentTemp <= vegData.temp[1];
    const humiditySuitability = currentHumidity >= vegData.humidity[0] && currentHumidity <= vegData.humidity[1];

    // 4. Soil suitability analysis
    const pHSuitability = soilPH >= vegData.soilPH[0] && soilPH <= vegData.soilPH[1];
    const soilTypeSuitability = vegData.soilType.includes(soilType);

    // 5. Economic viability calculation
    const totalSeedCost = vegData.seedCostPerHectare * farmSize;
    const expectedRevenue = vegData.expectedYieldPerHectare * farmSize * vegData.averageMarketPrice;
    const expectedProfit = expectedRevenue * vegData.profitMargin;
    const profitPerHectare = expectedProfit / farmSize;
    const breakEvenPoint = totalSeedCost / vegData.profitMargin;
    const budgetSufficient = budget >= totalSeedCost * 1.5; // Include 50% buffer for other costs

    // 6. Disease risk assessment
    const diseaseRisk = calculateDiseaseRisk(vegData, currentTemp, currentHumidity, soilType);

    // 7. Water requirement calculation
    const totalWaterNeeded = vegData.waterRequirements * farmSize; // mm per season
    const irrigationCost = calculateIrrigationCost(totalWaterNeeded);

    // 8. Overall recommendation score (0-100)
    let score = 0;
    if (tempSuitability) score += 20;
    if (humiditySuitability) score += 15;
    if (pHSuitability) score += 20;
    if (soilTypeSuitability) score += 15;
    if (budgetSufficient) score += 15;
    if (diseaseRisk === "Low") score += 10;
    else if (diseaseRisk === "Medium") score += 5;
    
    // Add market demand bonus
    if (vegData.marketDemand === "Very High") score += 5;
    else if (vegData.marketDemand === "High") score += 3;

    // 9. Generate recommendation level
    let recommendation = "";
    let actionPlan = [];

    if (score >= 80) {
      recommendation = "Highly Recommended";
      actionPlan = [
        "Excellent conditions for growing this vegetable",
        "Proceed with planting as planned",
        "Expected high profitability"
      ];
    } else if (score >= 60) {
      recommendation = "Recommended with Modifications";
      actionPlan = generateModificationPlan(vegData, {
        tempSuitability, humiditySuitability, pHSuitability, 
        soilTypeSuitability, budgetSufficient, diseaseRisk
      });
    } else {
      recommendation = "Not Recommended";
      actionPlan = [
        "Current conditions not suitable for this vegetable",
        "Consider alternative crops or wait for better conditions",
        "Significant risk of crop failure"
      ];
    }

    // 10. Generate planting calendar
    const plantingCalendar = generatePlantingCalendar(vegData);

    res.json({
      vegetable: vegetable,
      location: city,
      recommendation: recommendation,
      score: score,
      
      // Environmental analysis
      environmental: {
        currentTemp: currentTemp,
        optimalTempRange: vegData.temp,
        tempSuitability: tempSuitability,
        currentHumidity: currentHumidity,
        optimalHumidityRange: vegData.humidity,
        humiditySuitability: humiditySuitability
      },

      // Soil analysis
      soil: {
        currentPH: soilPH,
        optimalPHRange: vegData.soilPH,
        pHSuitability: pHSuitability,
        currentSoilType: soilType,
        preferredSoilTypes: vegData.soilType,
        soilTypeSuitability: soilTypeSuitability,
        nutrientRequirements: {
          nitrogen: vegData.nitrogenNeeds,
          phosphorus: vegData.phosphorusNeeds,
          potassium: vegData.potassiumNeeds,
          organicMatter: vegData.organicMatter
        }
      },

      // Economic analysis
      economics: {
        farmSize: farmSize,
        budget: budget,
        totalSeedCost: totalSeedCost,
        expectedYield: vegData.expectedYieldPerHectare * farmSize,
        expectedRevenue: expectedRevenue,
        expectedProfit: expectedProfit,
        profitPerHectare: profitPerHectare,
        breakEvenPoint: breakEvenPoint,
        budgetSufficient: budgetSufficient,
        marketPrice: vegData.averageMarketPrice,
        marketDemand: vegData.marketDemand
      },

      // Agricultural details
      cultivation: {
        plantingSeasons: vegData.plantingSeasons,
        daysToMaturity: vegData.daysToMaturity,
        harvestWindow: vegData.harvestWindow,
        plantingDepth: vegData.plantingDepth,
        spacing: vegData.spacing,
        waterRequirements: vegData.waterRequirements,
        irrigationFrequency: vegData.irrigationFrequency,
        totalWaterNeeded: totalWaterNeeded,
        irrigationCost: irrigationCost
      },

      // Risk assessment
      risks: {
        diseaseRisk: diseaseRisk,
        commonDiseases: vegData.commonDiseases,
        diseaseRiskFactors: vegData.diseaseRiskFactors,
        preventionMeasures: generatePreventionMeasures(vegData.commonDiseases)
      },

      // Companion planting
      companionPlanting: {
        beneficialCompanions: vegData.companionPlants,
        plantsToAvoid: vegData.avoidPlants,
        ecosystemBenefits: "Improved soil health, natural pest control, enhanced biodiversity"
      },

      // Practical advice
      practicalAdvice: {
        harvestingTips: vegData.harvesting,
        storageTips: vegData.storage,
        actionPlan: actionPlan,
        plantingCalendar: plantingCalendar
      }
    });

  } catch (error) {
    console.error("Error in farmer recommendation:", error);
    res.status(500).json({ error: "Failed to generate recommendation" });
  }
});

// Helper functions for comprehensive analysis
function calculateDiseaseRisk(vegData, temp, humidity, soilType) {
  let riskScore = 0;
  
  // Check temperature-related disease risks
  if (temp < vegData.temp[0] || temp > vegData.temp[1]) riskScore += 2;
  
  // Check humidity-related risks
  if (humidity > 80) riskScore += 2;
  if (humidity < 40) riskScore += 1;
  
  // Check soil-related risks
  if (!vegData.soilType.includes(soilType)) riskScore += 1;
  
  // Specific disease risk factors
  vegData.diseaseRiskFactors.forEach(factor => {
    if (factor.includes("humidity") && humidity > 75) riskScore += 1;
    if (factor.includes("drainage") && soilType === "clay") riskScore += 1;
    if (factor.includes("wet") && humidity > 80) riskScore += 1;
  });

  if (riskScore <= 2) return "Low";
  if (riskScore <= 4) return "Medium";
  return "High";
}

function calculateIrrigationCost(waterNeeded) {
  // Simplified irrigation cost calculation (varies by region)
  const costPerMM = 0.05; // USD per mm per hectare
  return waterNeeded * costPerMM;
}

function generateModificationPlan(vegData, suitability) {
  const plan = [];
  
  if (!suitability.tempSuitability) {
    plan.push(`Adjust planting time - optimal temperature range is ${vegData.temp[0]}°C to ${vegData.temp[1]}°C`);
  }
  
  if (!suitability.pHSuitability) {
    plan.push(`Adjust soil pH to ${vegData.soilPH[0]}-${vegData.soilPH[1]} range using lime or sulfur`);
  }
  
  if (!suitability.soilTypeSuitability) {
    plan.push(`Improve soil structure - add organic matter for better drainage/retention`);
  }
  
  if (!suitability.budgetSufficient) {
    plan.push(`Consider smaller planting area or seek additional funding`);
  }
  
  if (suitability.diseaseRisk !== "Low") {
    plan.push(`Implement preventive measures against ${vegData.commonDiseases.join(", ")}`);
  }

  return plan;
}

function generatePreventionMeasures(diseases) {
  const measures = [];
  
  diseases.forEach(disease => {
    if (disease.includes("Mildew") || disease.includes("Blight")) {
      measures.push("Improve air circulation, avoid overhead watering");
    }
    if (disease.includes("Aphids")) {
      measures.push("Use beneficial insects, neem oil spray");
    }
    if (disease.includes("Beetle") || disease.includes("Fly")) {
      measures.push("Row covers, beneficial nematodes, crop rotation");
    }
    if (disease.includes("Rot")) {
      measures.push("Improve drainage, avoid overwatering");
    }
  });

  return [...new Set(measures)]; // Remove duplicates
}

function generatePlantingCalendar(vegData) {
  const calendar = {};
  
  vegData.plantingSeasons.forEach(season => {
    let months = [];
    switch(season) {
      case "Early Spring":
        months = ["March", "April"];
        break;
      case "Late Spring":
        months = ["April", "May"];
        break;
      case "Spring":
        months = ["March", "April", "May"];
        break;
      case "Summer":
        months = ["June", "July"];
        break;
      case "Early Summer":
        months = ["June"];
        break;
      case "Fall":
        months = ["September", "October"];
        break;
      case "Winter":
        months = ["December", "January", "February"];
        break;
    }
    
    months.forEach(month => {
      calendar[month] = {
        activity: "Planting",
        details: `Plant ${vegData.variety} variety, ${vegData.plantingDepth}cm deep, ${vegData.spacing}cm spacing`
      };
    });
  });

  return calendar;
}

// New comprehensive plant simulation that combines CSV data with agricultural intelligence
app.post("/api/simulate-vegetable-farming", async (req, res) => {
  const { 
    plant, 
    temp, 
    humidity, 
    aqi, 
    city,
    soilPH = 6.5, 
    soilType = "loamy", 
    farmSize = 1, 
    budget = 5000,
    plantingMonth = "Spring"
  } = req.body;

  if (!plant) {
    return res.status(400).json({ error: "Plant selection required" });
  }

  try {
    // 1. Get comprehensive CSV data (now our primary source)
    const csvPlantData = await getPlantRecommendation(plant);
    if (!csvPlantData) {
      return res.status(404).json({ error: "Plant not found in CSV database" });
    }

    // 2. Get any additional comprehensive data (for backup/enhancement)
    const comprehensiveData = getComprehensiveVegetableData(plant);

    // 3. Create merged plant profile prioritizing CSV data
    const plantProfile = {
      name: plant,
      // Environmental from CSV (primary source)
      tempRange: [csvPlantData.minTemp, csvPlantData.maxTemp],
      humidityRange: [csvPlantData.minHumidity, csvPlantData.maxHumidity],
      aqiRange: [csvPlantData.minAqi, csvPlantData.maxAqi],
      
      // Soil requirements from CSV
      soilPH: [csvPlantData.minSoilPH, csvPlantData.maxSoilPH],
      soilType: csvPlantData.soilTypes,
      
      // Agricultural data from CSV
      waterRequirements: csvPlantData.waterRequirements,
      daysToMaturity: csvPlantData.daysToMaturity,
      expectedYield: csvPlantData.expectedYieldPerHectare,
      marketPrice: csvPlantData.marketPricePerKg,
      seedCost: csvPlantData.seedCostPerHectare,
      
      // Physical planting specs from CSV
      spacing: csvPlantData.spacing,
      plantingDepth: csvPlantData.plantingDepth,
      harvestWindow: csvPlantData.harvestWindow,
      storageLife: csvPlantData.storageLife,
      
      // Agricultural management from CSV
      category: csvPlantData.category,
      companionPlants: csvPlantData.companionPlants,
      commonDiseases: csvPlantData.commonDiseases,
      plantingSeasons: csvPlantData.plantingSeasons,
      marketDemand: csvPlantData.marketDemand,
      
      // Nutrient requirements from CSV
      nitrogenNeeds: csvPlantData.nitrogenNeeds,
      phosphorusNeeds: csvPlantData.phosphorusNeeds,
      potassiumNeeds: csvPlantData.potassiumNeeds,
      
      // Use comprehensive data as backup only if CSV doesn't have it
      organicMatter: comprehensiveData?.organicMatter || "15-20%",
      drainageNeeds: comprehensiveData?.drainageNeeds || "well-drained"
    };

    // 4. Environmental suitability analysis
    const tempSuitability = temp >= plantProfile.minTemp && temp <= plantProfile.maxTemp;
    const humiditySuitability = humidity >= plantProfile.minHumidity && humidity <= plantProfile.maxHumidity;
    const aqiSuitability = aqi >= plantProfile.minAqi && aqi <= plantProfile.maxAqi;

    // 5. Soil suitability
    const pHSuitability = soilPH >= plantProfile.minSoilPH && soilPH <= plantProfile.maxSoilPH;
    const soilTypeSuitability = plantProfile.soilTypes && plantProfile.soilTypes.includes(soilType);

    // 6. Seasonal suitability analysis
    const seasonalSuitability = assessSeasonalSuitability(plantProfile, plantingMonth);
    console.log(`Seasonal Analysis for ${plant} in ${plantingMonth}:`, {
      suitable: seasonalSuitability.suitable,
      score: seasonalSuitability.score,
      message: seasonalSuitability.message,
      optimalSeasons: plantProfile.plantingSeasons
    });

    // 7. Calculate base farming costs (fixed costs regardless of yield)
    const seedCost = plantProfile.seedCost * farmSize;

    // 8. Enhanced risk assessment with seasonal factors (BEFORE growth simulation)
    const diseaseRisk = getSeasonalDiseaseRisk(plantProfile, plantingMonth, temp, humidity);
    const weatherRisk = assessWeatherRisk(temp, humidity, plantProfile);
    const marketRisk = assessMarketRisk(plantProfile.marketDemand);

    // 9. Growth factor calculations for simulation
    const environmentalFactor = calculateEnvironmentalFactor(
      temp, humidity, aqi, 
      [plantProfile.minTemp, plantProfile.maxTemp], 
      [plantProfile.minHumidity, plantProfile.maxHumidity], 
      [plantProfile.minAqi, plantProfile.maxAqi]
    );
    
    const soilFactor = calculateSoilFactor(soilPH, soilType, plantProfile);
    const seasonalGrowthFactor = getSeasonalGrowthFactor(plantProfile, plantingMonth);
    
    // Weighted combination: environmental and soil are primary, seasonal modifies the result
    const baseGrowthFactor = (environmentalFactor + soilFactor) / 2;
    const overallGrowthFactor = baseGrowthFactor * seasonalGrowthFactor;
    
    console.log(`Growth Factors for ${plant}:`, {
      environmental: environmentalFactor.toFixed(2),
      soil: soilFactor.toFixed(2), 
      seasonal: seasonalGrowthFactor.toFixed(2),
      baseGrowth: baseGrowthFactor.toFixed(2),
      overall: overallGrowthFactor.toFixed(2)
    });

    // 10. Generate realistic growth curve with crop-specific parameters
    // Base carrying capacity represents maximum biomass potential (scaled to 100)
    const K0 = 100; // Base carrying capacity (normalized to 100 for easier understanding)
    const K = K0 * overallGrowthFactor; // Adjusted carrying capacity based on conditions
    
    // Dynamic growth rate based on conditions - poor conditions = slower growth
    let r = 0.08; // Base growth rate
    if (overallGrowthFactor > 0.8) r = 0.12; // Excellent conditions = faster growth
    else if (overallGrowthFactor < 0.5) r = 0.04; // Poor conditions = much slower growth
    else if (overallGrowthFactor < 0.7) r = 0.06; // Moderate conditions = slower growth
    
    // Initial biomass starts very small
    const N0 = 1; // Initial biomass
    const growthSeries = [];

    // Generate growth curve over the actual crop maturity period
    for (let t = 0; t <= plantProfile.daysToMaturity; t += Math.max(1, Math.floor(plantProfile.daysToMaturity / 30))) {
      // Standard logistic growth equation
      const N = K / (1 + ((K - N0) / N0) * Math.exp(-r * t));
      
      // Add realistic growth variations due to disease and weather stress
      let stressAdjustment = 1.0;
      if (diseaseRisk === "High") stressAdjustment *= (0.7 + 0.3 * Math.random()); // Random disease impact
      if (weatherRisk === "High") stressAdjustment *= (0.8 + 0.2 * Math.random()); // Random weather stress
      
      const adjustedBiomass = N * stressAdjustment;
      
      growthSeries.push({ 
        day: t, 
        biomass: adjustedBiomass,
        healthIndex: Math.min(100, (adjustedBiomass / K) * 100) // Health relative to potential under current conditions
      });
    }
    
    // Ensure final data point at maturity
    if (growthSeries[growthSeries.length - 1].day < plantProfile.daysToMaturity) {
      const finalT = plantProfile.daysToMaturity;
      const finalN = K / (1 + ((K - N0) / N0) * Math.exp(-r * finalT));
      let finalStress = 1.0;
      if (diseaseRisk === "High") finalStress *= 0.7;
      if (weatherRisk === "High") finalStress *= 0.8;
      const finalBiomass = finalN * finalStress;
      
      growthSeries.push({
        day: finalT,
        biomass: finalBiomass,
        healthIndex: Math.min(100, (finalBiomass / K) * 100)
      });
    }

    // 11. Preliminary budget check for scoring (full economic analysis comes later)
    const preliminaryTotalCosts = seedCost * 2.5; // Quick estimate for scoring only
    const budgetSufficient = budget >= preliminaryTotalCosts;

    // 12. Generate farming recommendations with seasonal considerations
    const overallScore = calculateFarmingScore({
      tempSuitability, humiditySuitability, aqiSuitability,
      pHSuitability, soilTypeSuitability, budgetSufficient,
      diseaseRisk, marketDemand: plantProfile.marketDemand,
      seasonalSuitability: seasonalSuitability.suitable
    });
    
    console.log(`Final Scores for ${plant} in ${plantingMonth}:`, {
      overallScore: overallScore,
      seasonalSuitable: seasonalSuitability.suitable,
      seasonalBonus: seasonalSuitability.suitable ? '+5 points' : '0 points',
      finalBiomass: growthSeries[growthSeries.length - 1]?.biomass?.toFixed(1) || 'N/A',
      finalHealth: growthSeries[growthSeries.length - 1]?.healthIndex?.toFixed(1) + '%' || 'N/A',
      growthRate: r.toFixed(3),
      carryingCapacity: K.toFixed(1)
    });

    // 13. Realistic Economic Analysis - AFTER growth simulation and risk assessment
    // Calculate yield adjustment factor based on actual growth simulation results
    const cropBiomass = growthSeries[growthSeries.length - 1].biomass;
    const cropHealthIndex = growthSeries[growthSeries.length - 1].healthIndex;
    
    // Enhanced yield adjustment that considers both biomass achievement and health index
    let baseYieldAdjustment = Math.min(1.0, cropBiomass / K0); // Biomass-based adjustment
    let healthAdjustment = Math.min(1.0, cropHealthIndex / 100); // Health-based adjustment
    
    // Combined yield adjustment (weighted average, prioritizing health for realistic farming)
    let yieldAdjustmentFactor = (baseYieldAdjustment * 0.6) + (healthAdjustment * 0.4);
    
    // Additional harsh reality checks for severe conditions
    if (!tempSuitability || !humiditySuitability) {
      yieldAdjustmentFactor *= 0.7; // 30% additional penalty for unsuitable temp/humidity
    }
    if (!pHSuitability || !soilTypeSuitability) {
      yieldAdjustmentFactor *= 0.8; // 20% additional penalty for unsuitable soil
    }
    if (!seasonalSuitability.suitable) {
      yieldAdjustmentFactor *= 0.6; // 40% penalty for wrong planting season
    }
    if (diseaseRisk === 'High') {
      yieldAdjustmentFactor *= 0.85; // 15% penalty for high disease risk
    }
    if (weatherRisk === 'High') {
      yieldAdjustmentFactor *= 0.9; // 10% penalty for high weather risk
    }
    
    // Ensure minimum adjustment factor (some yield is always possible, even if tiny)
    yieldAdjustmentFactor = Math.max(0.05, Math.min(1.0, yieldAdjustmentFactor));
    
    // Calculate realistic adjusted yield
    const idealYield = plantProfile.expectedYield * farmSize;
    const adjustedYield = idealYield * yieldAdjustmentFactor;
    
    // Calculate all farming costs 
    const irrigationPlan = generateIrrigationPlan(plantProfile, temp, humidity, farmSize);
    const fertilizationPlan = generateFertilizationPlan(plantProfile, soilType);
    
    const irrigationCost = irrigationPlan.cost;
    const fertilizationCost = fertilizationPlan.cost;
    
    // ENVIRONMENTAL AND SEASONAL COST ADJUSTMENTS
    // Poor conditions increase costs due to extra inputs, monitoring, and corrective measures
    
    // Temperature stress adjustment
    const tempOptimal = (plantProfile.minTemp + plantProfile.maxTemp) / 2;
    const tempDeviation = Math.abs(temp - tempOptimal);
    const tempStressFactor = 1 + (tempDeviation * 0.03); // 3% cost increase per degree deviation
    
    // Humidity stress adjustment  
    const humidityOptimal = (plantProfile.minHumidity + plantProfile.maxHumidity) / 2;
    const humidityDeviation = Math.abs(humidity - humidityOptimal);
    const humidityStressFactor = 1 + (humidityDeviation * 0.01); // 1% cost increase per humidity point deviation
    
    // Soil condition cost adjustments
    const pHOptimal = (plantProfile.minSoilPH + plantProfile.maxSoilPH) / 2;
    const pHDeviation = Math.abs(soilPH - pHOptimal);
    const pHAdjustmentFactor = 1 + (pHDeviation * 0.08); // 8% cost increase per pH unit deviation
    
    const soilTypeAdjustment = (plantProfile.soilTypes && plantProfile.soilTypes.includes(soilType)) ? 1.0 : 1.25; // 25% increase for unsuitable soil
    
    // Seasonal timing cost adjustments
    const seasonalCostFactor = seasonalSuitability.suitable ? 1.0 : 
      (seasonalSuitability.score > 0.7 ? 1.15 : 
       (seasonalSuitability.score > 0.3 ? 1.35 : 1.6)); // Wrong season dramatically increases costs
    
    // Weather risk cost adjustments
    const weatherCostMultiplier = {
      'Low': 1.0,
      'Medium': 1.15,
      'High': 1.4  // High weather risk requires protective measures
    };
    const weatherCostFactor = weatherCostMultiplier[weatherRisk] || 1.0;
    
    // Combined environmental stress factor
    const environmentalStressFactor = tempStressFactor * humidityStressFactor * 
                                    pHAdjustmentFactor * soilTypeAdjustment * 
                                    seasonalCostFactor * weatherCostFactor;
    
    // Enhanced realistic farming costs per hectare with comprehensive adjustments
    const baseLaborCost = 800; // Base labor cost per hectare
    const baseEquipmentCost = 300; // Base equipment cost per hectare
    const basePestControlCost = 150; // Base pest control cost per hectare
    const baseHarvestingCost = 200; // Base harvesting cost per hectare
    const baseMiscCost = 100; // Base miscellaneous cost per hectare
    
    // Regional cost adjustment factor (default 1.0 for moderate cost regions)
    const regionalCostFactor = 1.0; // Could be adjusted based on location in future
    
    // Crop-specific cost adjustments
    const cropComplexityFactor = {
      'Tomatoes': 1.3, 'Peppers': 1.2, 'Eggplant': 1.2, 'Cucumbers': 1.1,
      'Corn': 0.9, 'Beans Lima': 0.8, 'Beans Snap': 0.8, 'Peas': 0.8,
      'Carrots': 0.9, 'Radishes': 0.7, 'Lettuce': 0.8, 'Spinach': 0.8,
      'Broccoli': 1.1, 'Cabbage': 1.0, 'Cauliflower': 1.1,
      'Onions': 1.0, 'Garlic': 1.0, 'Leeks': 1.0,
      'Pumpkins': 1.1, 'Squash': 1.1, 'Watermelons': 1.2, 'Muskmelons (Cantaloupe)': 1.2,
      'Asparagus': 1.4, 'Celery': 1.3, 'Okra': 1.0, 'Turnips': 0.8,
      'Beets': 0.9, 'Parsnips': 0.9, 'Chard Swiss': 0.9, 'Parsley': 1.0
    };
    
    const cropFactor = cropComplexityFactor[plant] || 1.0;
    
    // Disease risk adjustment - higher disease risk = higher pest control costs
    const diseaseRiskMultiplier = {
      'Low': 1.0,
      'Medium': 1.2,
      'High': 1.5
    };
    
    const diseaseMultiplier = diseaseRiskMultiplier[diseaseRisk] || 1.0;
    
    // Calculate adjusted costs with FULL environmental impact
    const laborCost = baseLaborCost * farmSize * regionalCostFactor * cropFactor * environmentalStressFactor;
    const equipmentCost = baseEquipmentCost * farmSize * regionalCostFactor * environmentalStressFactor;
    const pestControlCost = basePestControlCost * farmSize * regionalCostFactor * diseaseMultiplier * environmentalStressFactor;
    const harvestingCost = baseHarvestingCost * farmSize * regionalCostFactor * cropFactor * (yieldAdjustmentFactor > 0.5 ? 1.0 : 1.5); // Higher harvesting costs for poor yields
    const miscCost = baseMiscCost * farmSize * regionalCostFactor * environmentalStressFactor;
    
    // Total comprehensive costs
    const totalCosts = seedCost + irrigationCost + fertilizationCost + 
                      laborCost + equipmentCost + pestControlCost + 
                      harvestingCost + miscCost;
    
    // Revenue calculation based on ADJUSTED yield
    const idealRevenue = idealYield * plantProfile.marketPrice;
    const adjustedRevenue = adjustedYield * plantProfile.marketPrice;
    
    // Realistic profit calculation
    const estimatedProfit = adjustedRevenue - totalCosts;
    const profitPerHectare = estimatedProfit / farmSize;
    const actualBudgetSufficient = budget >= totalCosts; // For display only
    const profitMargin = adjustedRevenue > 0 ? (estimatedProfit / adjustedRevenue) : 0;
    const roi = totalCosts > 0 ? (estimatedProfit / totalCosts) * 100 : 0;
    
    console.log(`ENVIRONMENTAL IMPACT ANALYSIS for ${plant}:`, {
      tempSuitability: tempSuitability ? "✅" : "❌",
      humiditySuitability: humiditySuitability ? "✅" : "❌", 
      soilSuitability: (pHSuitability && soilTypeSuitability) ? "✅" : "❌",
      seasonalTiming: seasonalSuitability.suitable ? "✅" : "❌",
      diseaseRisk: diseaseRisk,
      weatherRisk: weatherRisk,
      environmentalStressFactor: environmentalStressFactor.toFixed(2) + "x",
      yieldAdjustmentFactor: (yieldAdjustmentFactor * 100).toFixed(1) + "%"
    });

    console.log(`UPDATED Economic Reality Check for ${plant}:`, {
      idealYield: idealYield.toFixed(0) + " kg",
      adjustedYield: adjustedYield.toFixed(0) + " kg", 
      yieldLoss: ((1 - yieldAdjustmentFactor) * 100).toFixed(1) + "%",
      idealRevenue: "$" + idealRevenue.toFixed(0),
      adjustedRevenue: "$" + adjustedRevenue.toFixed(0),
      totalCosts: "$" + totalCosts.toFixed(0),
      realProfit: "$" + estimatedProfit.toFixed(0),
      profitMargin: (profitMargin * 100).toFixed(1) + "%",
      roi: roi.toFixed(1) + "%"
    });

    const farmingAdvice = generateFarmingAdvice(plantProfile, {
      tempSuitability, humiditySuitability, pHSuitability, 
      soilTypeSuitability, diseaseRisk, overallScore,
      seasonalSuitability: seasonalSuitability.suitable,
      seasonalMessage: seasonalSuitability.message
    });

    // 14. Seasonal timing recommendations with CSV data
    const seasonalRecommendations = generateSeasonalRecommendations(plantProfile, plantingMonth);

    // 15. Final result interpretation based on realistic growth simulation
    let result = "Your crop will thrive!";
    let statusColor = "green";
    const finalBiomass = growthSeries[growthSeries.length - 1].biomass;
    const finalHealthIndex = growthSeries[growthSeries.length - 1].healthIndex;
    
    // Result based on both biomass achievement and health index
    if (finalHealthIndex < 30 || finalBiomass < 20) {
      result = `Crop failure likely - poor growing conditions. Health: ${finalHealthIndex.toFixed(0)}%`;
      statusColor = "red";
    } else if (finalHealthIndex < 50 || finalBiomass < 40) {
      result = `Crop will struggle - expect reduced yields. Health: ${finalHealthIndex.toFixed(0)}%`;
      statusColor = "orange";
    } else if (finalHealthIndex < 70 || finalBiomass < 60) {
      result = `Moderate success expected. Health: ${finalHealthIndex.toFixed(0)}%`;
      statusColor = "yellow";
    } else if (finalHealthIndex < 85 || finalBiomass < 80) {
      result = `Good growing conditions. Health: ${finalHealthIndex.toFixed(0)}%`;
      statusColor = "lightgreen";
    } else {
      result = `Excellent conditions! Health: ${finalHealthIndex.toFixed(0)}%`;
      statusColor = "green";
    }
    
    // Add seasonal timing context
    if (!seasonalSuitability.suitable) {
      result += ` ⚠️ ${seasonalSuitability.message}`;
    } else if (seasonalSuitability.message) {
      result += ` ✅ ${seasonalSuitability.message}`;
    }

    res.json({
      // Basic info
      plant: plant,
      location: city || "Not specified",
      overallScore: overallScore,
      result: result,
      statusColor: statusColor,
      
      // Environmental analysis
      environmental: {
        temperature: {
          current: temp,
          optimal: plantProfile.tempRange,
          suitable: tempSuitability,
          advice: tempSuitability ? "Temperature is ideal" : `Adjust to ${plantProfile.tempRange[0]}-${plantProfile.tempRange[1]}°C range`
        },
        humidity: {
          current: humidity,
          optimal: plantProfile.humidityRange,
          suitable: humiditySuitability,
          advice: humiditySuitability ? "Humidity is ideal" : `Maintain ${plantProfile.humidityRange[0]}-${plantProfile.humidityRange[1]}% humidity`
        },
        airQuality: {
          current: aqi,
          optimal: plantProfile.aqiRange,
          suitable: aqiSuitability,
          advice: aqiSuitability ? "Air quality is suitable" : "Consider air quality improvements"
        }
      },

      // Seasonal analysis
      seasonal: {
        selectedSeason: plantingMonth,
        optimalSeasons: plantProfile.plantingSeasons,
        suitable: seasonalSuitability.suitable,
        score: Math.round(seasonalSuitability.score * 100),
        message: seasonalSuitability.message,
        risk: seasonalSuitability.risk,
        growthFactor: Math.round(seasonalGrowthFactor * 100)
      },

      // Soil analysis
      soil: {
        pH: {
          current: soilPH,
          optimal: plantProfile.soilPH,
          suitable: pHSuitability,
          adjustment: pHSuitability ? "No adjustment needed" : 
            soilPH < plantProfile.soilPH[0] ? "Add lime to increase pH" : "Add sulfur to decrease pH"
        },
        type: {
          current: soilType,
          preferred: plantProfile.soilType,
          suitable: soilTypeSuitability,
          improvement: soilTypeSuitability ? "Soil type is suitable" : "Add organic matter to improve soil structure"
        },
        nutrients: {
          nitrogen: plantProfile.nitrogenNeeds,
          phosphorus: plantProfile.phosphorusNeeds,
          potassium: plantProfile.potassiumNeeds,
          organicMatter: plantProfile.organicMatter
        }
      },

      // Economic viability with comprehensive real costs
      economics: {
        farmSize: farmSize,
        budget: budget,
        costs: {
          seeds: seedCost,
          irrigation: irrigationCost,
          fertilizer: fertilizationCost,
          labor: laborCost,
          equipment: equipmentCost,
          pestControl: pestControlCost,
          harvesting: harvestingCost,
          miscellaneous: miscCost,
          total: totalCosts,
          estimated_total: totalCosts // Flutter app expects this field name
        },
        returns: {
          idealYield: idealYield,
          adjustedYield: adjustedYield,
          yieldLossPercent: ((1 - yieldAdjustmentFactor) * 100).toFixed(1) + "%",
          idealRevenue: idealRevenue,
          adjustedRevenue: adjustedRevenue,
          revenue: adjustedRevenue, // Flutter app expects this field name for display
          profit: estimatedProfit,
          profitPerHectare: profitPerHectare,
          profitMargin: (profitMargin * 100).toFixed(1),
          roi: roi.toFixed(1)
        },
        // COMPREHENSIVE Economic Viability Assessment
        viability: calculateComprehensiveViability({
          budget, totalCosts, estimatedProfit, yieldAdjustmentFactor,
          tempSuitability, humiditySuitability, aqiSuitability,
          pHSuitability, soilTypeSuitability, seasonalSuitability,
          diseaseRisk, weatherRisk, plantProfile
        }),
        breakEven: totalCosts > 0 ? (totalCosts / plantProfile.marketPrice).toFixed(0) + " kg" : "N/A",
        marketDemand: plantProfile.marketDemand,
        costPerKg: adjustedYield > 0 ? (totalCosts / adjustedYield).toFixed(2) : "N/A",
        yieldReality: yieldAdjustmentFactor < 0.5 ? "Crop likely to fail" : yieldAdjustmentFactor < 0.8 ? "Reduced yields expected" : "Good yields expected",
        profitability: estimatedProfit > 0 ? "Profitable" : estimatedProfit === 0 ? "Break-even" : "Loss expected",
        viabilityScore: calculateViabilityScore({
          budgetRatio: budget / totalCosts,
          profitMargin: profitMargin,
          yieldAdjustmentFactor: yieldAdjustmentFactor,
          environmentalSuitability: (tempSuitability + humiditySuitability + aqiSuitability) / 3,
          soilSuitability: (pHSuitability + soilTypeSuitability) / 2,
          seasonalSuitability: seasonalSuitability.suitable,
          riskLevel: (diseaseRisk === 'High' || weatherRisk === 'High') ? 'High' : 
                    (diseaseRisk === 'Medium' || weatherRisk === 'Medium') ? 'Medium' : 'Low'
        }),
        riskFactors: identifyRiskFactors({
          temp, humidity, aqi, soilPH, soilType, plantingMonth,
          plantProfile, diseaseRisk, weatherRisk, budget, totalCosts
        })
      },

      // Growth simulation
      growth: {
        series: growthSeries,
        daysToMaturity: plantProfile.daysToMaturity,
        finalBiomass: finalBiomass,
        finalHealthIndex: finalHealthIndex,
        maxPotentialBiomass: K,
        actualGrowthRate: r,
        growthFactor: overallGrowthFactor,
        growthSummary: `Achieved ${finalBiomass.toFixed(1)}/${K.toFixed(1)} potential biomass (${finalHealthIndex.toFixed(0)}% health)`
      },

      // Risk management with CSV disease data
      risks: {
        disease: {
          level: diseaseRisk,
          commonDiseases: plantProfile.commonDiseases,
          prevention: generateDiseasePreventionPlan(plantProfile.commonDiseases)
        },
        weather: {
          level: weatherRisk,
          mitigation: generateWeatherMitigation(weatherRisk, plantProfile)
        },
        market: {
          level: marketRisk,
          demand: plantProfile.marketDemand,
          advice: "Monitor local market prices, consider contract farming"
        }
      },

      // Practical farming guidance with CSV data
      farming: {
        irrigation: irrigationPlan,
        fertilization: fertilizationPlan,
        planting: {
          seasons: plantProfile.plantingSeasons,
          depth: plantProfile.plantingDepth + " cm",
          spacing: plantProfile.spacing + " cm apart",
          category: plantProfile.category
        },
        companion_planting: {
          beneficial: plantProfile.companionPlants,
          benefits: "Improved pest control, soil health, and biodiversity"
        },
        seasonal: seasonalRecommendations,
        harvesting: {
          estimatedDate: calculateHarvestDate(plantingMonth, plantProfile.daysToMaturity),
          window: plantProfile.harvestWindow + " days",
          storageLife: plantProfile.storageLife + " days",
          signs: "Monitor plant maturity indicators specific to crop"
        }
      },

      // Action plan
      recommendations: farmingAdvice,
      
      // Success probability
      successProbability: Math.min(100, overallScore).toFixed(0) + "%"
    });

  } catch (error) {
    console.error("Error in vegetable farming simulation:", error);
    res.status(500).json({ error: "Failed to generate farming simulation" });
  }
});

// Helper functions for farming simulation
function calculateEnvironmentalFactor(temp, humidity, aqi, tempRange, humidityRange, aqiRange) {
  let factor = 1.0;
  
  // Temperature factor - only penalize if outside optimal range
  if (temp < tempRange[0]) {
    const tempDeviation = tempRange[0] - temp;
    factor -= Math.min(0.4, tempDeviation * 0.02);
  } else if (temp > tempRange[1]) {
    const tempDeviation = temp - tempRange[1];
    factor -= Math.min(0.4, tempDeviation * 0.02);
  }
  
  // Humidity factor - only penalize if outside optimal range
  if (humidity < humidityRange[0]) {
    const humidityDeviation = humidityRange[0] - humidity;
    factor -= Math.min(0.3, humidityDeviation * 0.01);
  } else if (humidity > humidityRange[1]) {
    const humidityDeviation = humidity - humidityRange[1];
    factor -= Math.min(0.3, humidityDeviation * 0.01);
  }
  
  // AQI factor - more precise calculation
  if (aqi < aqiRange[0]) {
    const aqiDeviation = aqiRange[0] - aqi;
    factor -= Math.min(0.2, aqiDeviation * 0.01);
  } else if (aqi > aqiRange[1]) {
    const aqiDeviation = aqi - aqiRange[1];
    factor -= Math.min(0.2, aqiDeviation * 0.01);
  }
  
  return Math.max(0.2, factor);
}

function calculateSoilFactor(soilPH, soilType, plantProfile) {
  let factor = 1.0;
  
  // pH factor - only penalize if outside optimal range
  if (plantProfile.minSoilPH !== undefined && soilPH < plantProfile.minSoilPH) {
    const pHDeviation = plantProfile.minSoilPH - soilPH;
    factor -= Math.min(0.3, pHDeviation * 0.1);
  } else if (plantProfile.maxSoilPH !== undefined && soilPH > plantProfile.maxSoilPH) {
    const pHDeviation = soilPH - plantProfile.maxSoilPH;
    factor -= Math.min(0.3, pHDeviation * 0.1);
  }
  
  // Soil type factor
  if (plantProfile.soilTypes && !plantProfile.soilTypes.includes(soilType)) {
    factor -= 0.2;
  }
  
  return Math.max(0.3, factor);
}

function assessDiseaseRisk(temp, humidity, soilType, plantProfile) {
  let riskLevel = 0;
  
  if (humidity > 80) riskLevel += 2;
  if (temp < 15 || temp > 30) riskLevel += 1;
  if (soilType === "clay" && humidity > 70) riskLevel += 1;
  if (plantProfile.commonDiseases.length > 3) riskLevel += 1;
  
  if (riskLevel <= 1) return "Low";
  if (riskLevel <= 3) return "Medium";
  return "High";
}

function assessWeatherRisk(temp, humidity, plantProfile) {
  // Check if plantProfile has the required temperature data
  if (plantProfile.minTemp !== undefined && plantProfile.maxTemp !== undefined) {
    if (temp < plantProfile.minTemp - 5 || temp > plantProfile.maxTemp + 5) {
      return "High";
    }
  }
  
  // Check humidity ranges - use plant profile if available, otherwise use general ranges
  if (plantProfile.minHumidity !== undefined && plantProfile.maxHumidity !== undefined) {
    if (humidity < plantProfile.minHumidity - 10 || humidity > plantProfile.maxHumidity + 10) {
      return "High";
    }
    if (humidity < plantProfile.minHumidity || humidity > plantProfile.maxHumidity) {
      return "Medium";
    }
  } else {
    // Fallback general humidity ranges
    if (humidity < 30 || humidity > 90) {
      return "Medium";
    }
  }
  
  return "Low";
}

function assessMarketRisk(marketDemand) {
  // Market risk based on demand level from CSV
  switch(marketDemand) {
    case "Very High":
    case "High":
      return "Low";
    case "Medium":
      return "Medium";
    case "Low":
      return "High";
    default:
      return "Medium";
  }
}

function calculateFarmingScore({
  tempSuitability, humiditySuitability, aqiSuitability,
  pHSuitability, soilTypeSuitability, budgetSufficient,
  diseaseRisk, marketDemand, seasonalSuitability
}) {
  let score = 0;
  
  // Environmental factors (40 points total)
  if (tempSuitability) score += 16;
  if (humiditySuitability) score += 16;
  if (aqiSuitability) score += 8;
  
  // Soil factors (25 points total)
  if (pHSuitability) score += 15;
  if (soilTypeSuitability) score += 10;
  
  // Economic factors (20 points total)
  if (budgetSufficient) score += 8;
  // Market demand scoring (0-12 points)
  if (marketDemand === "Very High") score += 12;
  else if (marketDemand === "High") score += 9;
  else if (marketDemand === "Medium") score += 6;
  else if (marketDemand === "Low") score += 3;
  
  // Risk factors (10 points total) - disease risk penalty
  if (diseaseRisk === "Low") score += 10;
  else if (diseaseRisk === "Medium") score += 7;
  else if (diseaseRisk === "High") score += 3;
  
  // Seasonal timing factor (5 points)
  if (seasonalSuitability === true) score += 5;
  
  // Total possible: 40 + 25 + 20 + 10 + 5 = 100 points exactly
  
  return Math.min(100, Math.max(0, score));
}

function generateFarmingAdvice(plantProfile, conditions) {
  const advice = [];
  
  // Seasonal timing advice (high priority)
  if (conditions.seasonalSuitability === false) {
    advice.push(`❌ SEASONAL TIMING ISSUE: ${conditions.seasonalMessage}`);
  } else if (conditions.seasonalMessage && conditions.seasonalMessage.includes("consider")) {
    advice.push(`⚠️ ${conditions.seasonalMessage}`);
  } else if (conditions.seasonalMessage) {
    advice.push(`✅ ${conditions.seasonalMessage}`);
  }
  
  if (!conditions.tempSuitability) {
    advice.push(`Temperature adjustment needed: optimal range is ${plantProfile.minTemp}-${plantProfile.maxTemp}°C`);
  }
  
  if (!conditions.pHSuitability) {
    advice.push(`Soil pH adjustment required: target ${plantProfile.minSoilPH}-${plantProfile.maxSoilPH}`);
  }
  
  if (conditions.diseaseRisk === "High") {
    advice.push("Implement preventive disease management strategies");
  }
  
  if (conditions.overallScore >= 80) {
    advice.push("Excellent growing conditions - proceed with confidence");
  } else if (conditions.overallScore >= 60) {
    advice.push("Good growing potential with some modifications");
  } else {
    advice.push("Consider alternative crops or significant improvements");
  }
  
  advice.push(`Water requirement: ${plantProfile.waterRequirements}mm per season`);
  advice.push(`Expected maturity: ${plantProfile.daysToMaturity} days`);
  
  return advice;
}

function generateSeasonalRecommendations(plantProfile, currentMonth) {
  const recommendations = {};
  
  plantProfile.plantingSeasons.forEach(season => {
    recommendations[season] = {
      optimal: season,
      activities: [
        "Soil preparation and testing",
        "Seed planting at appropriate depth",
        "Initial watering and monitoring"
      ]
    };
  });
  
  return recommendations;
}

function generateIrrigationPlan(plantProfile, temp, humidity, farmSize) {
  const baseWater = plantProfile.waterRequirements * farmSize;
  let adjustedWater = baseWater;
  
  // More nuanced temperature adjustment
  const tempOptimal = (plantProfile.minTemp + plantProfile.maxTemp) / 2;
  const tempDeviation = Math.abs(temp - tempOptimal);
  const tempAdjustment = 1 + (tempDeviation * 0.02); // 2% increase per degree deviation
  
  // More nuanced humidity adjustment
  const humidityOptimal = (plantProfile.minHumidity + plantProfile.maxHumidity) / 2;
  const humidityDeviation = Math.abs(humidity - humidityOptimal);
  const humidityAdjustment = 1 + (humidityDeviation * 0.005); // 0.5% increase per humidity point deviation
  
  adjustedWater = baseWater * tempAdjustment * humidityAdjustment;
  
  // Water cost varies by region and method
  const waterCostPerMM = {
    'drip': 0.03,      // Most efficient
    'sprinkler': 0.05, // Moderate efficiency
    'flood': 0.08      // Least efficient
  };
  
  // Choose irrigation method based on water requirements
  let method = "Drip irrigation";
  let costMultiplier = waterCostPerMM.drip;
  
  if (adjustedWater > baseWater * 1.3) {
    method = "Sprinkler irrigation for high water needs";
    costMultiplier = waterCostPerMM.sprinkler;
  } else if (adjustedWater > baseWater * 1.5) {
    method = "Flood irrigation for very high water needs";
    costMultiplier = waterCostPerMM.flood;
  }
  
  // Additional costs for irrigation infrastructure
  const infrastructureCost = farmSize * 200; // $200/hectare for irrigation setup
  const maintenanceCost = farmSize * 50; // $50/hectare annual maintenance
  
  const totalCost = (adjustedWater * costMultiplier) + infrastructureCost + maintenanceCost;
  
  return {
    totalWaterNeeded: Math.round(adjustedWater),
    frequency: temp > 25 ? "Daily" : temp > 20 ? "Every 2 days" : "Every 3 days",
    cost: totalCost,
    method: method,
    breakdown: {
      waterCost: adjustedWater * costMultiplier,
      infrastructure: infrastructureCost,
      maintenance: maintenanceCost
    },
    efficiency: method.includes("Drip") ? "High" : method.includes("Sprinkler") ? "Medium" : "Low"
  };
}

function generateFertilizationPlan(plantProfile, soilType) {
  // Nutrient requirements mapping
  const nutrientMultipliers = {
    low: 0.5,
    medium: 1.0,
    high: 1.5
  };

  // Base fertilizer rates per hectare
  const baseNitrogen = 120; // kg/ha
  const basePhosphorus = 60; // kg/ha
  const basePotassium = 100; // kg/ha

  // Calculate actual needs based on CSV data
  const nitrogenNeeded = baseNitrogen * (nutrientMultipliers[plantProfile.nitrogenNeeds] || 1.0);
  const phosphorusNeeded = basePhosphorus * (nutrientMultipliers[plantProfile.phosphorusNeeds] || 1.0);
  const potassiumNeeded = basePotassium * (nutrientMultipliers[plantProfile.potassiumNeeds] || 1.0);

  // Soil adjustment factors
  const soilAdjustment = {
    "sandy": { N: 1.2, P: 1.0, K: 1.3 },
    "loamy": { N: 1.0, P: 1.0, K: 1.0 },
    "clay": { N: 0.9, P: 1.1, K: 0.8 },
    "sandy-loam": { N: 1.1, P: 1.0, K: 1.1 },
    "clay-loam": { N: 0.95, P: 1.05, K: 0.9 }
  };

  const soilFactor = soilAdjustment[soilType] || soilAdjustment["loamy"];

  // Adjusted fertilizer recommendations
  const finalNitrogen = Math.round(nitrogenNeeded * soilFactor.N);
  const finalPhosphorus = Math.round(phosphorusNeeded * soilFactor.P);
  const finalPotassium = Math.round(potassiumNeeded * soilFactor.K);

  // Fertilizer costs (per kg)
  const fertilizerCosts = {
    nitrogen: 1.2, // USD per kg
    phosphorus: 1.8,
    potassium: 1.5,
    organic: 0.3
  };

  const fertilizerCost = (finalNitrogen * fertilizerCosts.nitrogen) + 
                        (finalPhosphorus * fertilizerCosts.phosphorus) + 
                        (finalPotassium * fertilizerCosts.potassium) +
                        (500 * fertilizerCosts.organic); // 500kg organic matter

  return {
    schedule: [
      {
        week: 0,
        fertilizer: "Base fertilizer application",
        npk: `${Math.round(finalNitrogen * 0.4)}-${Math.round(finalPhosphorus * 0.8)}-${Math.round(finalPotassium * 0.4)} kg/ha`,
        notes: `Apply before planting based on ${plantProfile.nitrogenNeeds} N, ${plantProfile.phosphorusNeeds} P, ${plantProfile.potassiumNeeds} K needs`
      },
      {
        week: 3,
        fertilizer: "First side-dress",
        npk: `${Math.round(finalNitrogen * 0.3)}-0-${Math.round(finalPotassium * 0.3)} kg/ha`,
        notes: `Nitrogen boost for ${plantProfile.category} during active growth`
      },
      {
        week: 6,
        fertilizer: "Second side-dress",
        npk: `${Math.round(finalNitrogen * 0.3)}-${Math.round(finalPhosphorus * 0.2)}-${Math.round(finalPotassium * 0.3)} kg/ha`,
        notes: "Support flowering/fruiting stage if applicable"
      }
    ],
    totalNutrients: {
      nitrogen: finalNitrogen + " kg/ha",
      phosphorus: finalPhosphorus + " kg/ha", 
      potassium: finalPotassium + " kg/ha",
      organicMatter: plantProfile.organicMatter || "15-20%"
    },
    cost: fertilizerCost,
    soilAdjustment: `Adjusted for ${soilType} soil type`,
    cropSpecific: `Customized for ${plantProfile.category} with ${plantProfile.nitrogenNeeds}/${plantProfile.phosphorusNeeds}/${plantProfile.potassiumNeeds} NPK requirements`
  };
}

function generateDiseasePreventionPlan(diseases) {
  if (!diseases || diseases.length === 0) {
    return ["Regular monitoring", "Good sanitation practices"];
  }
  
  const plan = [];
  diseases.forEach(disease => {
    if (disease.includes("Mildew")) {
      plan.push("Improve air circulation, avoid overhead watering");
    }
    if (disease.includes("Blight")) {
      plan.push("Use resistant varieties, copper-based fungicides");
    }
    if (disease.includes("Aphids")) {
      plan.push("Beneficial insects, neem oil application");
    }
  });
  
  return plan.length > 0 ? plan : ["Standard IPM practices"];
}

function generateWeatherMitigation(weatherRisk, plantProfile) {
  if (weatherRisk === "High") {
    return [
      "Consider greenhouse or tunnel protection",
      "Install irrigation system for drought protection",
      "Use row covers for temperature protection"
    ];
  }
  if (weatherRisk === "Medium") {
    return [
      "Monitor weather forecasts closely",
      "Have protection materials ready",
      "Adjust watering schedule as needed"
    ];
  }
  return ["Standard weather monitoring sufficient"];
}

function calculateHarvestDate(plantingMonth, daysToMaturity) {
  // Map planting seasons to approximate month numbers
  const seasonToMonth = {
    "Winter": 1,      // January
    "Early Spring": 3, // March  
    "Spring": 4,      // April
    "Late Spring": 5, // May
    "Early Summer": 6, // June
    "Summer": 7,      // July
    "Fall": 9,        // September
    "Early Fall": 9,  // September
    "Late Fall": 10   // October
  };
  
  const startMonth = seasonToMonth[plantingMonth] || 4; // Default to April
  const monthsToMaturity = Math.round(daysToMaturity / 30);
  const harvestMonth = ((startMonth + monthsToMaturity - 1) % 12) + 1;
  
  const months = ["January", "February", "March", "April", "May", "June", 
                  "July", "August", "September", "October", "November", "December"];
  
  return months[harvestMonth - 1] + ` (${monthsToMaturity} months from ${plantingMonth} planting)`;
}

function assessSeasonalSuitability(plantProfile, plantingMonth) {
  const optimalSeasons = plantProfile.plantingSeasons || [];
  
  // Exact match gets highest score
  if (optimalSeasons.includes(plantingMonth)) {
    return {
      suitable: true,
      score: 1.0,
      message: `Perfect timing! ${plantingMonth} is optimal for ${plantProfile.name}`,
      risk: "Low"
    };
  }
  
  // Check for related seasons (e.g., Spring vs Late Spring)
  const seasonalMatches = {
    "Spring": ["Early Spring", "Late Spring"],
    "Early Spring": ["Spring"],  
    "Late Spring": ["Spring", "Summer"],
    "Summer": ["Late Spring", "Early Summer"],
    "Fall": ["Early Fall", "Late Fall"],
    "Winter": ["Early Winter", "Late Winter"]
  };
  
  const relatedSeasons = seasonalMatches[plantingMonth] || [];
  const hasRelatedMatch = relatedSeasons.some(season => optimalSeasons.includes(season));
  
  if (hasRelatedMatch) {
    return {
      suitable: true,
      score: 0.7,
      message: `Good timing, but consider ${optimalSeasons[0]} for optimal results`,
      risk: "Medium"
    };
  }
  
  // Poor timing
  return {
    suitable: false,
    score: 0.3,
    message: `Poor timing! ${plantProfile.name} is best planted in ${optimalSeasons.join(' or ')}, not ${plantingMonth}`,
    risk: "High"
  };
}

function getSeasonalGrowthFactor(plantProfile, plantingMonth) {
  const seasonalSuitability = assessSeasonalSuitability(plantProfile, plantingMonth);
  
  // Season affects growth rate
  const seasonFactors = {
    "Spring": 1.0,      // Optimal growing season
    "Late Spring": 1.1,  // Peak growing season  
    "Summer": 0.9,      // Heat stress potential
    "Fall": 0.8,        // Shorter days
    "Winter": 0.5       // Minimal growth
  };
  
  const baseFactor = seasonFactors[plantingMonth] || 0.7;
  return baseFactor * seasonalSuitability.score;
}

function getSeasonalDiseaseRisk(plantProfile, plantingMonth, temp, humidity) {
  let baseRisk = assessDiseaseRisk(temp, humidity, "loamy", plantProfile);
  
  // Seasonal disease pressure adjustments
  const seasonalRiskFactors = {
    "Spring": 0.8,      // Lower disease pressure
    "Late Spring": 0.9,
    "Summer": 1.3,      // Higher disease pressure (heat + humidity)
    "Fall": 1.0,
    "Winter": 0.6       // Lower disease activity
  };
  
  const riskMultiplier = seasonalRiskFactors[plantingMonth] || 1.0;
  
  if (baseRisk === "Low" && riskMultiplier > 1.2) return "Medium";
  if (baseRisk === "Medium" && riskMultiplier > 1.2) return "High"; 
  if (baseRisk === "High" && riskMultiplier < 0.8) return "Medium";
  
  return baseRisk;
}

// Real AI Chatbot endpoint using Google Gemini (FREE!)
app.post("/api/ai-chat", async (req, res) => {
  try {
    const { prompt } = req.body;
    
    if (!prompt || prompt.trim().length === 0) {
      return res.status(400).json({ 
        error: "Prompt is required",
        response: "Please provide a question about farming."
      });
    }

    // Check if Gemini API key is configured
    if (!GEMINI_API_KEY || GEMINI_API_KEY === "YOUR_GEMINI_API_KEY_HERE") {
      console.log("⚠️  Gemini API key not configured, using fallback response system");
      try {
        const fallbackResponse = generateFarmingResponse(prompt);
        return res.json({ 
          response: fallbackResponse + "\n\n*Note: Using offline mode. Configure Gemini API key for full AI capabilities.*",
          timestamp: new Date().toISOString(),
          mode: "fallback"
        });
      } catch (fallbackError) {
        console.error("❌ Fallback system error:", fallbackError.message);
        return res.json({ 
          response: "🚜 **AirWise Farming Assistant**\n\nI'm temporarily unavailable but I'm here to help with your farming questions! Please try again in a moment.\n\n*Note: Please ensure your question is properly formatted and try again.*",
          timestamp: new Date().toISOString(),
          mode: "error",
          error: "System temporarily unavailable"
        });
      }
    }

    // Use real Google Gemini AI with new syntax
    const systemContext = `You are AirWise AI, an expert agricultural advisor specializing in sustainable farming, crop management, and agricultural technology. You have decades of experience helping farmers optimize their yields while protecting the environment.

Your expertise covers:
🌱 Crop Selection & Rotation - optimal varieties for different climates and seasons
🌍 Soil Health Management - pH, nutrients, organic matter, and soil testing
💧 Water Management - irrigation efficiency, conservation, and drought adaptation  
🦠 Integrated Pest Management - organic solutions, beneficial insects, disease prevention
🌡️ Climate Adaptation - dealing with extreme weather, season extension
🚜 Farm Economics - cost optimization, market analysis, sustainable profitability
📊 Agricultural Technology - precision farming, sensors, data-driven decisions

Provide practical, actionable advice with specific recommendations including:
- Exact measurements, timelines, and application rates when relevant
- Cost considerations and ROI estimates
- Safety precautions and environmental impact
- Regional adaptation tips
- Step-by-step implementation guides

Always prioritize sustainable, environmentally-friendly solutions that balance productivity with ecological health.`;

    const enhancedPrompt = `${systemContext}

Farmer's Question: ${prompt}

Please provide detailed, practical guidance tailored to this specific farming question. Include actionable steps, measurements, timelines, and considerations for different farm sizes and budgets.`;

    console.log("🤖 Asking Gemini AI...");
    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: enhancedPrompt,
    });
    
    const aiResponse = response.text;

    console.log("✅ Gemini AI responded successfully");
    res.json({
      response: aiResponse,
      timestamp: new Date().toISOString(),
      model: "gemini-2.5-flash",
      mode: "ai"
    });

  } catch (error) {
    console.error("❌ Gemini AI error:", error.message);
    
    // Fallback to rule-based system if AI fails
    console.log("🔄 Falling back to offline response system");
    
    try {
      const fallbackResponse = generateFarmingResponse(req.body.prompt);
      res.json({ 
        response: fallbackResponse + "\n\n*Note: AI service temporarily unavailable, using expert knowledge base.*",
        timestamp: new Date().toISOString(),
        mode: "fallback",
        error: "AI service unavailable"
      });
    } catch (fallbackError) {
      console.error("❌ Fallback system error:", fallbackError.message);
      res.json({ 
        response: "🚜 **AirWise Farming Assistant**\n\nI'm temporarily unavailable but I'm here to help with your farming questions! Please try again in a moment.\n\n*Note: Please ensure your question is properly formatted and try again.*",
        timestamp: new Date().toISOString(),
        mode: "error",
        error: "System temporarily unavailable"
      });
    }
  }
});

// Genetic Algorithm Optimization endpoint
app.post("/api/genetic-optimization", (req, res) => {
  try {
    console.log("🧬 Received genetic optimization request");
    console.log("Request body:", JSON.stringify(req.body, null, 2));
    
    const { 
      farmConfig,
      objectives,
      gaParameters 
    } = req.body;
    
    // Validate required fields
    if (!farmConfig || !objectives || !gaParameters) {
      throw new Error("Missing required fields: farmConfig, objectives, or gaParameters");
    }
    
    console.log("Farm config:", farmConfig);
    console.log("Objectives:", objectives);
    console.log("GA parameters:", gaParameters);
    
    // Simulate genetic algorithm optimization
    const results = simulateGeneticOptimization(farmConfig, objectives, gaParameters);
    
    console.log("✅ Genetic optimization completed successfully");
    console.log("Results structure:", {
      bestSolution: !!results.bestSolution,
      convergenceData: !!results.convergenceData,
      metrics: !!results.metrics,
      recommendations: !!results.recommendations
    });
    
    res.json({
      success: true,
      results,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error("❌ Genetic optimization error:", error);
    console.error("Error stack:", error.stack);
    res.status(500).json({ 
      success: false,
      error: "Optimization failed",
      message: error.message || "Unable to complete genetic algorithm optimization."
    });
  }
});

function generateFarmingResponse(prompt) {
  try {
    // Validate input
    if (!prompt || typeof prompt !== 'string') {
      return `🚜 **AirWise Farming Assistant**

I can help you with sustainable farming practices including:
• Crop selection and planting
• Soil management and fertilization  
• Pest and disease control
• Water management and irrigation
• Harvest timing and storage

For detailed, personalized advice on any farming topic, please ask specific questions about your crops or farming challenges.

*Note: Full AI capabilities will provide much more detailed guidance once configured.*`;
    }

    // Simple fallback response when AI is unavailable
    const promptLower = prompt.toLowerCase();
    
    // Quick plant detection
    const plants = ['tomato', 'carrot', 'lettuce', 'corn', 'soybean', 'wheat', 'pepper', 'cucumber', 'onion', 'potato'];
    const mentionedPlant = plants.find(plant => promptLower.includes(plant));
    
    if (mentionedPlant) {
      try {
        const plantData = getComprehensiveVegetableData(mentionedPlant);
        
        // Check if plantData exists and has properties
        if (plantData && typeof plantData === 'object') {
          return `🌱 **Basic Guide for ${mentionedPlant.charAt(0).toUpperCase() + mentionedPlant.slice(1)}**
    
**Quick Facts:**
• Days to maturity: ${plantData.daysToMaturity || '60-90 days'}
• Planting seasons: ${(plantData.plantingSeasons || ['Spring']).join(', ')}
• Water needs: ${plantData.waterRequirements || 'Moderate'}
• Spacing: ${plantData.spacing || '12-18 inches apart'}

**Essential Tips:**
• Choose sunny location with good drainage
• Prepare soil with compost
• Water consistently but don't overwater
• Monitor for pests and diseases
• Harvest when fruits reach proper size and color

*Note: For detailed, personalized advice, please configure the AI system for comprehensive guidance.*`;
        }
      } catch (error) {
        console.error("Error getting plant data:", error);
        // Continue to default response
      }
      
      // Fallback for when plant data is not available
      return `🌱 **Basic Guide for ${mentionedPlant.charAt(0).toUpperCase() + mentionedPlant.slice(1)}**
    
**General Growing Tips:**
• Days to maturity: Usually 60-90 days
• Planting seasons: Spring or Fall
• Water needs: Moderate, consistent watering
• Spacing: 12-18 inches apart typically

**Essential Tips:**
• Choose sunny location with good drainage
• Prepare soil with compost
• Water consistently but don't overwater
• Monitor for pests and diseases
• Harvest when fruits reach proper size and color

*Note: For detailed, personalized advice, please configure the AI system for comprehensive guidance.*`;
    }
    
    return `🚜 **AirWise Farming Assistant**

I can help you with sustainable farming practices including:
• Crop selection and planting
• Soil management and fertilization  
• Pest and disease control
• Water management and irrigation
• Harvest timing and storage

For detailed, personalized advice on any farming topic, please ask specific questions about your crops or farming challenges.

*Note: Full AI capabilities will provide much more detailed guidance once configured.*`;
    
  } catch (error) {
    console.error("Error in generateFarmingResponse:", error);
    return `🚜 **AirWise Farming Assistant**

I'm here to help with your farming questions! Please try asking about:
• Specific crops you want to grow
• Soil preparation and management
• Pest and disease control
• Irrigation and water management
• Harvest timing and storage

*Note: Full AI capabilities will provide much more detailed guidance once configured.*`;
  }
}



function simulateGeneticOptimization(farmConfig, objectives, gaParameters) {
  const { farmSize, budget, soilType, climateZone } = farmConfig;
  const { populationSize, generations, crossoverRate, mutationRate } = gaParameters;
  
  console.log(`🧬 Starting genetic algorithm optimization for ${farmSize} ha farm in ${climateZone} climate...`);
  
  // Initialize population with realistic constraints
  let population = initializeRealisticPopulation(populationSize, farmSize, budget, soilType, climateZone);
  
  const convergenceData = {
    fitnessHistory: [],
    sustainabilityHistory: [],
    yieldHistory: []
  };
  
  let bestSolution = null;
  let bestFitness = -1;
  
  // Evolution loop
  for (let generation = 0; generation < generations; generation++) {
    // Evaluate fitness for each chromosome
    population.forEach(chromosome => {
      chromosome.fitness = calculateRealWorldFitness(chromosome, objectives, farmConfig);
    });
    
    // Track best solution
    population.sort((a, b) => b.fitness - a.fitness);
    if (population[0].fitness > bestFitness) {
      bestFitness = population[0].fitness;
      bestSolution = JSON.parse(JSON.stringify(population[0]));
    }
    
    // Record convergence data
    const genStats = calculateGenerationStats(population, farmConfig);
    convergenceData.fitnessHistory.push(genStats.avgFitness);
    convergenceData.sustainabilityHistory.push(genStats.avgSustainability);
    convergenceData.yieldHistory.push(genStats.avgYield);
    
    // Selection, crossover, and mutation
    if (generation < generations - 1) {
      population = evolvePopulation(population, crossoverRate || 0.8, mutationRate || 0.1, farmSize, budget);
    }
    
    if (generation % 10 === 0) {
      console.log(`Generation ${generation}: Best fitness = ${bestFitness.toFixed(4)}`);
    }
  }
  
  // Calculate comprehensive metrics
  const metrics = calculateComprehensiveMetrics(bestSolution, farmConfig);
  
  return {
    bestSolution: {
      crops: bestSolution.crops,
      landAllocation: bestSolution.landUse,
      waterAllocation: bestSolution.waterAllocation,
      fertilizerAllocation: bestSolution.fertilizerAllocation,
      pesticidesUse: bestSolution.pesticidesUse,
      fitness: bestSolution.fitness
    },
    convergenceData,
    metrics,
    recommendations: generateSmartRecommendations(bestSolution, metrics, farmConfig)
  };
}

// Real-world crop database with scientific parameters
function getCropParameters(cropName) {
  const cropDB = {
    'Wheat': {
      maxYield: 8.5, // tonnes/ha (world record ~17, average 3-8)
      waterRequirement: 450, // mm/season
      nitrogenRequirement: 150, // kg N/ha
      marketPrice: 280, // USD/tonne
      seedCostPerHa: 180,
      pesticideCostPerHa: 120,
      laborCostPerHa: 350,
      machineryCostPerHa: 400,
      growingPeriod: 120, // days
      soilPreference: ['Loamy', 'Clayey'],
      climatePreference: ['Temperate', 'Mediterranean'],
      diseaseResistance: 0.7,
      droughtTolerance: 0.6
    },
    'Corn': {
      maxYield: 12.0, // tonnes/ha
      waterRequirement: 600,
      nitrogenRequirement: 200,
      marketPrice: 190,
      seedCostPerHa: 250,
      pesticideCostPerHa: 180,
      laborCostPerHa: 420,
      machineryCostPerHa: 500,
      growingPeriod: 140,
      soilPreference: ['Loamy', 'Silty'],
      climatePreference: ['Tropical', 'Temperate'],
      diseaseResistance: 0.6,
      droughtTolerance: 0.4
    },
    'Rice': {
      maxYield: 9.5,
      waterRequirement: 1200,
      nitrogenRequirement: 120,
      marketPrice: 420,
      seedCostPerHa: 150,
      pesticideCostPerHa: 200,
      laborCostPerHa: 600,
      machineryCostPerHa: 450,
      growingPeriod: 130,
      soilPreference: ['Clayey', 'Silty'],
      climatePreference: ['Tropical', 'Temperate'],
      diseaseResistance: 0.5,
      droughtTolerance: 0.2
    },
    'Soybeans': {
      maxYield: 4.5,
      waterRequirement: 500,
      nitrogenRequirement: 80, // Lower due to nitrogen fixation
      marketPrice: 450,
      seedCostPerHa: 200,
      pesticideCostPerHa: 140,
      laborCostPerHa: 300,
      machineryCostPerHa: 380,
      growingPeriod: 110,
      soilPreference: ['Loamy', 'Sandy'],
      climatePreference: ['Temperate', 'Tropical'],
      diseaseResistance: 0.65,
      droughtTolerance: 0.7
    },
    'Tomatoes': {
      maxYield: 75.0, // High value vegetable crop
      waterRequirement: 700,
      nitrogenRequirement: 250,
      marketPrice: 800,
      seedCostPerHa: 1200,
      pesticideCostPerHa: 800,
      laborCostPerHa: 2500,
      machineryCostPerHa: 600,
      growingPeriod: 90,
      soilPreference: ['Loamy', 'Sandy'],
      climatePreference: ['Mediterranean', 'Temperate'],
      diseaseResistance: 0.4,
      droughtTolerance: 0.5
    },
    'Potatoes': {
      maxYield: 45.0,
      waterRequirement: 550,
      nitrogenRequirement: 180,
      marketPrice: 250,
      seedCostPerHa: 800,
      pesticideCostPerHa: 300,
      laborCostPerHa: 800,
      machineryCostPerHa: 500,
      growingPeriod: 100,
      soilPreference: ['Sandy', 'Loamy'],
      climatePreference: ['Temperate', 'Mediterranean'],
      diseaseResistance: 0.5,
      droughtTolerance: 0.6
    },
    'Cotton': {
      maxYield: 2.5,
      waterRequirement: 800,
      nitrogenRequirement: 160,
      marketPrice: 1600,
      seedCostPerHa: 300,
      pesticideCostPerHa: 400,
      laborCostPerHa: 500,
      machineryCostPerHa: 600,
      growingPeriod: 180,
      soilPreference: ['Clayey', 'Loamy'],
      climatePreference: ['Arid', 'Tropical'],
      diseaseResistance: 0.6,
      droughtTolerance: 0.8
    },
    'Sugarcane': {
      maxYield: 85.0,
      waterRequirement: 1500,
      nitrogenRequirement: 200,
      marketPrice: 60,
      seedCostPerHa: 400,
      pesticideCostPerHa: 250,
      laborCostPerHa: 800,
      machineryCostPerHa: 700,
      growingPeriod: 365,
      soilPreference: ['Clayey', 'Loamy'],
      climatePreference: ['Tropical'],
      diseaseResistance: 0.7,
      droughtTolerance: 0.3
    }
  };
  
  return cropDB[cropName] || cropDB['Wheat'];
}

function initializeRealisticPopulation(populationSize, farmSize, budget, soilType, climateZone) {
  const population = [];
  const availableCrops = getClimateAdaptedCrops(climateZone, soilType);
  
  for (let i = 0; i < populationSize; i++) {
    const numCrops = Math.min(3 + Math.floor(Math.random() * 3), availableCrops.length); // 3-5 crops
    const selectedCrops = shuffleArray([...availableCrops]).slice(0, numCrops);
    
    const chromosome = {
      crops: selectedCrops,
      landUse: [],
      waterAllocation: [],
      fertilizerAllocation: [],
      pesticidesUse: [],
      fitness: 0
    };
    
    // Realistic land distribution
    let remainingLand = farmSize;
    for (let j = 0; j < numCrops; j++) {
      if (j === numCrops - 1) {
        chromosome.landUse.push(remainingLand);
      } else {
        const allocation = Math.random() * (remainingLand * 0.6) + remainingLand * 0.1;
        chromosome.landUse.push(allocation);
        remainingLand -= allocation;
      }
    }
    
    // Realistic input allocations based on crop requirements and budget constraints
    for (let j = 0; j < numCrops; j++) {
      const crop = selectedCrops[j];
      const cropData = getCropParameters(crop);
      const landArea = chromosome.landUse[j];
      
      // Water allocation (80-120% of optimal with budget constraints)
      const optimalWater = cropData.waterRequirement;
      const waterVariation = 0.8 + Math.random() * 0.4; // 80-120%
      chromosome.waterAllocation.push(optimalWater * waterVariation);
      
      // Fertilizer allocation (60-140% of optimal)
      const optimalN = cropData.nitrogenRequirement;
      const fertilizerVariation = 0.6 + Math.random() * 0.8; // 60-140%
      chromosome.fertilizerAllocation.push(optimalN * fertilizerVariation);
      
      // Pesticide use (conservative approach, 50-150% of recommended)
      const pesticidesVariation = 0.5 + Math.random() * 1.0;
      chromosome.pesticidesUse.push(cropData.pesticideCostPerHa * pesticidesVariation / 100);
    }
    
    population.push(chromosome);
  }
  
  return population;
}

function getClimateAdaptedCrops(climateZone, soilType) {
  const allCrops = ['Wheat', 'Corn', 'Rice', 'Soybeans', 'Tomatoes', 'Potatoes', 'Cotton', 'Sugarcane'];
  
  return allCrops.filter(crop => {
    const cropData = getCropParameters(crop);
    return cropData.climatePreference.includes(climateZone) && 
           cropData.soilPreference.includes(soilType);
  });
}

function shuffleArray(array) {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

function calculateRealWorldFitness(chromosome, objectives, farmConfig) {
  const yieldScore = calculateYieldScore(chromosome, farmConfig);
  const profitabilityScore = calculateProfitabilityScore(chromosome, farmConfig);
  const sustainabilityScore = calculateSustainabilityScore(chromosome, farmConfig);
  const waterEfficiencyScore = calculateWaterEfficiencyScore(chromosome, farmConfig);
  const diseaseResistanceScore = calculateDiseaseResistanceScore(chromosome, farmConfig);
  
  // Weighted fitness based on selected objectives
  let fitness = 0;
  let totalWeight = 0;
  
  if (objectives.optimizeYield) {
    fitness += yieldScore * 0.25;
    totalWeight += 0.25;
  }
  if (objectives.optimizeProfitability) {
    fitness += profitabilityScore * 0.30;
    totalWeight += 0.30;
  }
  if (objectives.optimizeSustainability) {
    fitness += sustainabilityScore * 0.20;
    totalWeight += 0.20;
  }
  if (objectives.optimizeWaterEfficiency) {
    fitness += waterEfficiencyScore * 0.15;
    totalWeight += 0.15;
  }
  if (objectives.optimizeDiseaseResistance) {
    fitness += diseaseResistanceScore * 0.10;
    totalWeight += 0.10;
  }
  
  return totalWeight > 0 ? fitness / totalWeight : 0;
}

// Doorenbos & Kassam water-yield relationship
function calculateWaterStressFactor(actualWater, optimalWater) {
  if (actualWater >= optimalWater) {
    // Excess water reduces yield due to waterlogging
    const excessRatio = actualWater / optimalWater;
    return Math.max(0.3, Math.min(1.0, 2.0 - excessRatio));
  } else {
    // Water deficit reduces yield linearly
    const deficitRatio = actualWater / optimalWater;
    return Math.max(0.2, 0.2 + 0.8 * deficitRatio);
  }
}

// Mitscherlich-Baule nutrient response model
function calculateNutrientResponseFactor(actualN, optimalN) {
  const c = 0.03; // Response coefficient
  const relativeN = actualN / optimalN;
  
  if (relativeN <= 1.0) {
    return 1.0 - Math.exp(-c * actualN);
  } else {
    // Excess fertilizer reduces efficiency and can harm yield
    const excess = relativeN - 1.0;
    const maxResponse = 1.0 - Math.exp(-c * optimalN);
    return Math.max(0.4, maxResponse * (1.0 - 0.2 * excess));
  }
}

function calculateYieldScore(chromosome, farmConfig) {
  let totalYield = 0;
  let maxPossibleYield = 0;
  
  for (let i = 0; i < chromosome.crops.length; i++) {
    const crop = chromosome.crops[i];
    const landArea = chromosome.landUse[i];
    const waterUse = chromosome.waterAllocation[i];
    const fertilizerUse = chromosome.fertilizerAllocation[i];
    
    const cropData = getCropParameters(crop);
    const maxYield = cropData.maxYield;
    const optimalWater = cropData.waterRequirement;
    const optimalNitrogen = cropData.nitrogenRequirement;
    
    // Scientific yield calculation
    const waterStressFactor = calculateWaterStressFactor(waterUse, optimalWater);
    const nutrientFactor = calculateNutrientResponseFactor(fertilizerUse, optimalNitrogen);
    const climateFactor = getClimateFactor(crop, farmConfig.climateZone);
    const soilFactor = getSoilFactor(crop, farmConfig.soilType);
    
    const actualYield = maxYield * waterStressFactor * nutrientFactor * climateFactor * soilFactor;
    
    totalYield += actualYield * landArea;
    maxPossibleYield += maxYield * landArea;
  }
  
  return maxPossibleYield > 0 ? Math.min(1.0, totalYield / maxPossibleYield) : 0;
}

function getClimateFactor(crop, climateZone) {
  const cropData = getCropParameters(crop);
  if (cropData.climatePreference.includes(climateZone)) {
    return 0.9 + Math.random() * 0.1; // 90-100% if climate is suitable
  }
  return 0.5 + Math.random() * 0.3; // 50-80% if climate is not optimal
}

function getSoilFactor(crop, soilType) {
  const cropData = getCropParameters(crop);
  if (cropData.soilPreference.includes(soilType)) {
    return 0.85 + Math.random() * 0.15; // 85-100% if soil is suitable
  }
  return 0.6 + Math.random() * 0.25; // 60-85% if soil is suboptimal
}

function calculateProfitabilityScore(chromosome, farmConfig) {
  let totalRevenue = 0;
  let totalCosts = 0;
  
  for (let i = 0; i < chromosome.crops.length; i++) {
    const crop = chromosome.crops[i];
    const landArea = chromosome.landUse[i];
    const waterUse = chromosome.waterAllocation[i];
    const fertilizerUse = chromosome.fertilizerAllocation[i];
    const pesticidesUse = chromosome.pesticidesUse[i];
    
    const cropData = getCropParameters(crop);
    
    // Calculate actual yield using scientific models
    const waterStressFactor = calculateWaterStressFactor(waterUse, cropData.waterRequirement);
    const nutrientFactor = calculateNutrientResponseFactor(fertilizerUse, cropData.nitrogenRequirement);
    const climateFactor = getClimateFactor(crop, farmConfig.climateZone);
    const soilFactor = getSoilFactor(crop, farmConfig.soilType);
    
    const actualYield = cropData.maxYield * waterStressFactor * nutrientFactor * climateFactor * soilFactor;
    
    // Revenue calculation with market dynamics
    const basePrice = cropData.marketPrice;
    const seasonalFactor = getSeasonalPriceFactor(crop);
    const qualityFactor = getQualityFactor(actualYield, cropData.maxYield);
    const marketPrice = basePrice * seasonalFactor * qualityFactor;
    
    totalRevenue += actualYield * landArea * marketPrice;
    
    // Comprehensive cost calculation
    const productionCosts = {
      seeds: landArea * cropData.seedCostPerHa,
      fertilizer: landArea * fertilizerUse * 1.2, // USD 1.2/kg N
      pesticides: landArea * pesticidesUse * 10, // USD 10/kg pesticides
      water: landArea * waterUse * 0.08, // USD 0.08/mm/ha
      labor: landArea * cropData.laborCostPerHa,
      machinery: landArea * cropData.machineryCostPerHa,
      storage: actualYield * landArea * 15, // USD 15/tonne storage
      transport: actualYield * landArea * 25, // USD 25/tonne transport
      insurance: landArea * 150, // USD 150/ha insurance
      landRent: landArea * 800, // USD 800/ha/year
    };
    
    totalCosts += Object.values(productionCosts).reduce((a, b) => a + b, 0);
  }
  
  // Economy of scale factor for larger farms
  const scaleFactor = getEconomyOfScaleFactor(chromosome.landUse.reduce((a, b) => a + b, 0));
  totalCosts *= scaleFactor;
  
  const profit = totalRevenue - totalCosts;
  const roi = totalRevenue > 0 ? profit / totalRevenue : -1.0;
  
  // Convert ROI to 0-1 score (typical farming ROI: 5-15%)
  return Math.max(0, Math.min(1, (roi + 0.2) / 0.4));
}

function calculateSustainabilityScore(chromosome, farmConfig) {
  let sustainabilitySum = 0;
  let totalLand = 0;
  
  for (let i = 0; i < chromosome.crops.length; i++) {
    const crop = chromosome.crops[i];
    const landArea = chromosome.landUse[i];
    const waterUse = chromosome.waterAllocation[i];
    const fertilizerUse = chromosome.fertilizerAllocation[i];
    const pesticidesUse = chromosome.pesticidesUse[i];
    
    const cropData = getCropParameters(crop);
    
    // Environmental impact factors
    const waterEfficiency = Math.max(0, 1 - Math.abs(waterUse - cropData.waterRequirement) / cropData.waterRequirement);
    const fertilizerEfficiency = Math.max(0, 1 - Math.abs(fertilizerUse - cropData.nitrogenRequirement) / cropData.nitrogenRequirement);
    const pesticideScore = Math.max(0, 1 - pesticidesUse / (cropData.pesticideCostPerHa / 100)); // Lower pesticide = higher score
    
    // Soil health impact (crop rotation and soil preservation)
    const soilHealthScore = getSoilHealthImpact(crop);
    
    // Biodiversity impact
    const biodiversityScore = getBiodiversityImpact(crop, pesticidesUse);
    
    // Carbon footprint (shorter growing period = lower footprint)
    const carbonScore = Math.max(0, 1 - cropData.growingPeriod / 365);
    
    const cropSustainability = (
      waterEfficiency * 0.25 +
      fertilizerEfficiency * 0.25 +
      pesticideScore * 0.2 +
      soilHealthScore * 0.15 +
      biodiversityScore * 0.1 +
      carbonScore * 0.05
    );
    
    sustainabilitySum += cropSustainability * landArea;
    totalLand += landArea;
  }
  
  return totalLand > 0 ? sustainabilitySum / totalLand : 0;
}

function calculateWaterEfficiencyScore(chromosome, farmConfig) {
  let totalWaterEfficiency = 0;
  let totalLand = 0;
  
  for (let i = 0; i < chromosome.crops.length; i++) {
    const crop = chromosome.crops[i];
    const landArea = chromosome.landUse[i];
    const waterUse = chromosome.waterAllocation[i];
    const fertilizerUse = chromosome.fertilizerAllocation[i];
    
    const cropData = getCropParameters(crop);
    
    // Calculate water productivity (yield per unit water)
    const waterStressFactor = calculateWaterStressFactor(waterUse, cropData.waterRequirement);
    const nutrientFactor = calculateNutrientResponseFactor(fertilizerUse, cropData.nitrogenRequirement);
    const climateFactor = getClimateFactor(crop, farmConfig.climateZone);
    const soilFactor = getSoilFactor(crop, farmConfig.soilType);
    
    const actualYield = cropData.maxYield * waterStressFactor * nutrientFactor * climateFactor * soilFactor;
    const waterProductivity = waterUse > 0 ? actualYield / waterUse : 0; // tonnes/mm
    
    // Normalize against crop-specific benchmarks
    const benchmarkProductivity = cropData.maxYield / cropData.waterRequirement;
    const efficiency = Math.min(1, waterProductivity / benchmarkProductivity);
    
    totalWaterEfficiency += efficiency * landArea;
    totalLand += landArea;
  }
  
  return totalLand > 0 ? totalWaterEfficiency / totalLand : 0;
}

function calculateDiseaseResistanceScore(chromosome, farmConfig) {
  let totalResistance = 0;
  let totalLand = 0;
  
  for (let i = 0; i < chromosome.crops.length; i++) {
    const crop = chromosome.crops[i];
    const landArea = chromosome.landUse[i];
    const pesticidesUse = chromosome.pesticidesUse[i];
    
    const cropData = getCropParameters(crop);
    
    // Base disease resistance of the crop
    let baseResistance = cropData.diseaseResistance;
    
    // Pesticide protection factor
    const pesticideProtection = Math.min(0.3, pesticidesUse * 0.05); // Max 30% boost from pesticides
    
    // Climate disease risk
    const climateRisk = getClimateDiseasePressure(farmConfig.climateZone);
    
    // Crop diversity bonus (monoculture = higher disease risk)
    const diversityBonus = chromosome.crops.length > 3 ? 0.1 : 0;
    
    const totalResistanceForCrop = Math.min(1, baseResistance + pesticideProtection + diversityBonus - climateRisk);
    
    totalResistance += totalResistanceForCrop * landArea;
    totalLand += landArea;
  }
  
  return totalLand > 0 ? totalResistance / totalLand : 0;
}

function getSeasonalPriceFactor(crop) {
  const seasonalFactors = {
    'Wheat': 1.1, 'Corn': 0.95, 'Rice': 1.05, 'Soybeans': 1.0,
    'Tomatoes': 1.15, 'Potatoes': 0.9, 'Cotton': 1.05, 'Sugarcane': 1.0
  };
  return seasonalFactors[crop] || 1.0;
}

function getQualityFactor(actualYield, maxYield) {
  const yieldRatio = actualYield / maxYield;
  if (yieldRatio > 0.8) return 1.1; // Premium for high quality
  if (yieldRatio > 0.6) return 1.0; // Standard quality
  return 0.85; // Discount for lower quality
}

function getEconomyOfScaleFactor(totalLandArea) {
  if (totalLandArea > 1000) return 0.85; // Large commercial farm
  if (totalLandArea > 500) return 0.90;  // Medium farm
  if (totalLandArea > 100) return 0.95;  // Small commercial farm
  return 1.0; // Subsistence farm
}

function getSoilHealthImpact(crop) {
  const soilImpact = {
    'Wheat': 0.8, 'Corn': 0.6, 'Rice': 0.5, 'Soybeans': 0.9, // Legumes improve soil
    'Tomatoes': 0.7, 'Potatoes': 0.6, 'Cotton': 0.5, 'Sugarcane': 0.4
  };
  return soilImpact[crop] || 0.7;
}

function getBiodiversityImpact(crop, pesticidesUse) {
  const baseImpact = {
    'Wheat': 0.7, 'Corn': 0.6, 'Rice': 0.5, 'Soybeans': 0.8,
    'Tomatoes': 0.6, 'Potatoes': 0.7, 'Cotton': 0.4, 'Sugarcane': 0.5
  };
  const base = baseImpact[crop] || 0.6;
  const pesticidePenalty = Math.min(0.3, pesticidesUse * 0.1);
  return Math.max(0.2, base - pesticidePenalty);
}

function getClimateDiseasePressure(climateZone) {
  const pressures = {
    'Tropical': 0.2, 'Temperate': 0.1, 'Arid': 0.05, 'Mediterranean': 0.08
  };
  return pressures[climateZone] || 0.1;
}

function calculateGenerationStats(population, farmConfig) {
  const avgFitness = population.reduce((sum, chr) => sum + chr.fitness, 0) / population.length;
  const avgSustainability = population.reduce((sum, chr) => sum + calculateSustainabilityScore(chr, farmConfig), 0) / population.length;
  const avgYield = population.reduce((sum, chr) => sum + calculateYieldScore(chr, farmConfig), 0) / population.length;
  
  return { avgFitness, avgSustainability, avgYield };
}

function evolvePopulation(population, crossoverRate, mutationRate, farmSize, budget) {
  const populationSize = population.length;
  const newPopulation = [];
  
  // Elitism - keep top 10% of population
  const eliteCount = Math.floor(populationSize * 0.1);
  population.sort((a, b) => b.fitness - a.fitness);
  for (let i = 0; i < eliteCount; i++) {
    newPopulation.push(JSON.parse(JSON.stringify(population[i])));
  }
  
  // Generate rest of population through selection, crossover, and mutation
  while (newPopulation.length < populationSize) {
    const parent1 = tournamentSelection(population, 3);
    const parent2 = tournamentSelection(population, 3);
    
    let offspring;
    if (Math.random() < crossoverRate) {
      offspring = crossover(parent1, parent2);
    } else {
      offspring = JSON.parse(JSON.stringify(parent1));
    }
    
    if (Math.random() < mutationRate) {
      mutate(offspring, farmSize, budget);
    }
    
    newPopulation.push(offspring);
  }
  
  return newPopulation;
}

function tournamentSelection(population, tournamentSize) {
  const tournament = [];
  for (let i = 0; i < tournamentSize; i++) {
    const randomIndex = Math.floor(Math.random() * population.length);
    tournament.push(population[randomIndex]);
  }
  tournament.sort((a, b) => b.fitness - a.fitness);
  return tournament[0];
}

function crossover(parent1, parent2) {
  const offspring = JSON.parse(JSON.stringify(parent1));
  
  // Single-point crossover for numerical arrays
  if (parent1.landUse.length === parent2.landUse.length) {
    const crossoverPoint = Math.floor(Math.random() * parent1.landUse.length);
    for (let i = crossoverPoint; i < parent1.landUse.length; i++) {
      offspring.landUse[i] = parent2.landUse[i];
      offspring.waterAllocation[i] = parent2.waterAllocation[i];
      offspring.fertilizerAllocation[i] = parent2.fertilizerAllocation[i];
      offspring.pesticidesUse[i] = parent2.pesticidesUse[i];
    }
  }
  
  return offspring;
}

function mutate(chromosome, farmSize, budget) {
  for (let i = 0; i < chromosome.landUse.length; i++) {
    // Mutate with 20% probability per gene
    if (Math.random() < 0.2) {
      const crop = chromosome.crops[i];
      const cropData = getCropParameters(crop);
      
      // Mutate water allocation (±20%)
      const waterMutation = (Math.random() - 0.5) * 0.4;
      chromosome.waterAllocation[i] = Math.max(
        cropData.waterRequirement * 0.5,
        Math.min(cropData.waterRequirement * 1.5, 
                chromosome.waterAllocation[i] * (1 + waterMutation))
      );
      
      // Mutate fertilizer allocation (±30%)
      const fertilizerMutation = (Math.random() - 0.5) * 0.6;
      chromosome.fertilizerAllocation[i] = Math.max(
        cropData.nitrogenRequirement * 0.3,
        Math.min(cropData.nitrogenRequirement * 1.8,
                chromosome.fertilizerAllocation[i] * (1 + fertilizerMutation))
      );
      
      // Mutate pesticide use (±50%)
      const pesticideMutation = (Math.random() - 0.5) * 1.0;
      chromosome.pesticidesUse[i] = Math.max(
        0,
        chromosome.pesticidesUse[i] * (1 + pesticideMutation)
      );
    }
  }
}

function calculateComprehensiveMetrics(bestSolution, farmConfig) {
  const totalYield = calculateActualTotalYield(bestSolution, farmConfig);
  const sustainability = calculateSustainabilityScore(bestSolution, farmConfig);
  const profitability = calculateProfitabilityScore(bestSolution, farmConfig);
  const waterEfficiency = calculateWaterEfficiencyScore(bestSolution, farmConfig);
  const diseaseResistance = calculateDiseaseResistanceScore(bestSolution, farmConfig);
  
  return {
    totalYield: totalYield.toFixed(2),
    sustainability: sustainability.toFixed(3),
    profitability: profitability.toFixed(3),
    waterEfficiency: waterEfficiency.toFixed(3),
    diseaseResistance: diseaseResistance.toFixed(3)
  };
}

function calculateActualTotalYield(chromosome, farmConfig) {
  let totalYield = 0;
  
  for (let i = 0; i < chromosome.crops.length; i++) {
    const crop = chromosome.crops[i];
    const landArea = chromosome.landUse[i];
    const waterUse = chromosome.waterAllocation[i];
    const fertilizerUse = chromosome.fertilizerAllocation[i];
    
    const cropData = getCropParameters(crop);
    const waterStressFactor = calculateWaterStressFactor(waterUse, cropData.waterRequirement);
    const nutrientFactor = calculateNutrientResponseFactor(fertilizerUse, cropData.nitrogenRequirement);
    const climateFactor = getClimateFactor(crop, farmConfig.climateZone);
    const soilFactor = getSoilFactor(crop, farmConfig.soilType);
    
    const actualYield = cropData.maxYield * waterStressFactor * nutrientFactor * climateFactor * soilFactor;
    totalYield += actualYield * landArea;
  }
  
  return totalYield;
}

function generateSmartRecommendations(bestSolution, metrics, farmConfig) {
  const recommendations = [];
  
  // Analyze yield optimization opportunities
  if (parseFloat(metrics.totalYield) < farmConfig.farmSize * 5) {
    recommendations.push("Consider higher-yielding crop varieties or improved cultivation techniques to increase productivity");
  }
  
  // Water efficiency recommendations
  if (parseFloat(metrics.waterEfficiency) < 0.7) {
    recommendations.push("Install drip irrigation or implement water-saving techniques to improve water use efficiency");
  }
  
  // Sustainability improvements
  if (parseFloat(metrics.sustainability) < 0.7) {
    recommendations.push("Adopt organic farming practices and reduce chemical inputs for better environmental sustainability");
  }
  
  // Profitability enhancements
  if (parseFloat(metrics.profitability) < 0.6) {
    recommendations.push("Focus on high-value crops and optimize input costs to improve farm profitability");
  }
  
  // Disease management
  if (parseFloat(metrics.diseaseResistance) < 0.6) {
    recommendations.push("Implement integrated pest management and consider disease-resistant crop varieties");
  }
  
  // Crop-specific recommendations
  const cropCounts = {};
  bestSolution.crops.forEach(crop => {
    cropCounts[crop] = (cropCounts[crop] || 0) + 1;
  });
  
  if (Object.keys(cropCounts).length < 3) {
    recommendations.push("Increase crop diversity to reduce disease risk and improve soil health through rotation");
  }
  
  // Climate-specific advice
  if (farmConfig.climateZone === 'Arid') {
    recommendations.push("Focus on drought-tolerant crops and water conservation techniques for arid climate conditions");
  } else if (farmConfig.climateZone === 'Tropical') {
    recommendations.push("Implement pest management strategies suitable for high humidity and temperature conditions");
  }
  
  return recommendations;
}

// COMPREHENSIVE Economic Viability Assessment Functions
function calculateComprehensiveViability({
  budget, totalCosts, estimatedProfit, yieldAdjustmentFactor,
  tempSuitability, humiditySuitability, aqiSuitability,
  pHSuitability, soilTypeSuitability, seasonalSuitability,
  diseaseRisk, weatherRisk, plantProfile
}) {
  // 1. Budget Analysis
  const budgetRatio = budget / totalCosts;
  let budgetStatus = "";
  
  if (budgetRatio >= 1.2) {
    budgetStatus = "Excellent budget - 20% safety margin";
  } else if (budgetRatio >= 1.0) {
    budgetStatus = "Sufficient budget";
  } else if (budgetRatio >= 0.8) {
    budgetStatus = "Tight budget - need $" + (totalCosts - budget).toFixed(0) + " more";
  } else {
    budgetStatus = "Insufficient budget - need $" + (totalCosts - budget).toFixed(0) + " more";
  }
  
  // 2. Risk Assessment
  const majorRisks = [];
  if (!tempSuitability) majorRisks.push("unsuitable temperature");
  if (!humiditySuitability) majorRisks.push("unsuitable humidity");
  if (!aqiSuitability) majorRisks.push("poor air quality");
  if (!pHSuitability) majorRisks.push("unsuitable soil pH");
  if (!soilTypeSuitability) majorRisks.push("unsuitable soil type");
  if (!seasonalSuitability.suitable) majorRisks.push("wrong planting season");
  if (diseaseRisk === 'High') majorRisks.push("high disease risk");
  if (weatherRisk === 'High') majorRisks.push("high weather risk");
  
  // 3. Yield Viability
  let yieldViability = "";
  if (yieldAdjustmentFactor >= 0.8) {
    yieldViability = "Good yields expected";
  } else if (yieldAdjustmentFactor >= 0.6) {
    yieldViability = "Moderate yields expected";
  } else if (yieldAdjustmentFactor >= 0.4) {
    yieldViability = "Poor yields expected";
  } else {
    yieldViability = "Crop likely to fail";
  }
  
  // 4. Profitability Analysis
  let profitViability = "";
  if (estimatedProfit > totalCosts * 0.3) {
    profitViability = "Highly profitable";
  } else if (estimatedProfit > totalCosts * 0.1) {
    profitViability = "Moderately profitable";
  } else if (estimatedProfit > 0) {
    profitViability = "Marginally profitable";
  } else {
    profitViability = "Loss expected";
  }
  
  // 5. Overall Viability Assessment
  if (majorRisks.length === 0 && budgetRatio >= 1.0 && estimatedProfit > 0) {
    return `✅ HIGHLY VIABLE - ${budgetStatus}, ${yieldViability}, ${profitViability}`;
  } else if (majorRisks.length <= 2 && budgetRatio >= 0.8 && estimatedProfit > 0) {
    return `⚠️ VIABLE WITH RISKS - ${budgetStatus}, ${yieldViability}. Risks: ${majorRisks.join(', ')}`;
  } else if (majorRisks.length <= 3 && budgetRatio >= 0.6) {
    return `⚠️ MARGINAL VIABILITY - ${budgetStatus}, ${yieldViability}. Major risks: ${majorRisks.join(', ')}`;
  } else {
    return `❌ NOT VIABLE - ${budgetStatus}, ${yieldViability}. Critical issues: ${majorRisks.join(', ')}`;
  }
}

function calculateViabilityScore({
  budgetRatio, profitMargin, yieldAdjustmentFactor,
  environmentalSuitability, soilSuitability, seasonalSuitability, riskLevel
}) {
  let score = 0;
  
  // Budget score (0-25 points)
  if (budgetRatio >= 1.2) score += 25;
  else if (budgetRatio >= 1.0) score += 20;
  else if (budgetRatio >= 0.8) score += 15;
  else if (budgetRatio >= 0.6) score += 10;
  else score += 5;
  
  // Profit margin score (0-25 points)
  if (profitMargin >= 0.3) score += 25;
  else if (profitMargin >= 0.2) score += 20;
  else if (profitMargin >= 0.1) score += 15;
  else if (profitMargin >= 0.05) score += 10;
  else if (profitMargin > 0) score += 5;
  
  // Yield potential score (0-20 points)
  score += Math.round(yieldAdjustmentFactor * 20);
  
  // Environmental suitability score (0-15 points)
  score += Math.round(environmentalSuitability * 15);
  
  // Soil suitability score (0-10 points)
  score += Math.round(soilSuitability * 10);
  
  // Seasonal suitability score (0-10 points)
  if (seasonalSuitability) score += 10;
  else score += 2;
  
  // Risk penalty (-15 to 0 points)
  if (riskLevel === 'Low') score += 0;
  else if (riskLevel === 'Medium') score -= 7;
  else score -= 15;
  
  return Math.max(0, Math.min(100, score));
}

function identifyRiskFactors({
  temp, humidity, aqi, soilPH, soilType, plantingMonth,
  plantProfile, diseaseRisk, weatherRisk, budget, totalCosts
}) {
  const risks = [];
  
  // Temperature risks
  const tempOptimal = (plantProfile.minTemp + plantProfile.maxTemp) / 2;
  const tempDeviation = Math.abs(temp - tempOptimal);
  if (tempDeviation > 5) {
    risks.push({
      factor: "Temperature",
      severity: tempDeviation > 10 ? "High" : "Medium",
      description: `${tempDeviation.toFixed(1)}°C deviation from optimal ${tempOptimal.toFixed(1)}°C`,
      impact: "Reduced growth and yield potential"
    });
  }
  
  // Humidity risks
  const humidityOptimal = (plantProfile.minHumidity + plantProfile.maxHumidity) / 2;
  const humidityDeviation = Math.abs(humidity - humidityOptimal);
  if (humidityDeviation > 15) {
    risks.push({
      factor: "Humidity",
      severity: humidityDeviation > 30 ? "High" : "Medium",
      description: `${humidityDeviation.toFixed(1)}% deviation from optimal ${humidityOptimal.toFixed(1)}%`,
      impact: "Increased water stress and disease susceptibility"
    });
  }
  
  // Soil risks
  const pHOptimal = (plantProfile.minSoilPH + plantProfile.maxSoilPH) / 2;
  const pHDeviation = Math.abs(soilPH - pHOptimal);
  if (pHDeviation > 0.5) {
    risks.push({
      factor: "Soil pH",
      severity: pHDeviation > 1.0 ? "High" : "Medium",
      description: `pH ${soilPH} vs optimal ${pHOptimal.toFixed(1)}`,
      impact: "Reduced nutrient uptake and plant health"
    });
  }
  
  if (plantProfile.soilTypes && !plantProfile.soilTypes.includes(soilType)) {
    risks.push({
      factor: "Soil Type",
      severity: "Medium",
      description: `${soilType} not in preferred types: ${plantProfile.soilTypes.join(', ')}`,
      impact: "Suboptimal growing conditions"
    });
  }
  
  // Seasonal risks
  if (!assessSeasonalSuitability(plantProfile, plantingMonth).suitable) {
    risks.push({
      factor: "Planting Season",
      severity: "High",
      description: `${plantingMonth} not optimal. Best: ${plantProfile.plantingSeasons.join(', ')}`,
      impact: "Significantly reduced yields and increased failure risk"
    });
  }
  
  // Disease risks
  if (diseaseRisk === 'High') {
    risks.push({
      factor: "Disease Pressure",
      severity: "High",
      description: `High risk for: ${plantProfile.commonDiseases.join(', ')}`,
      impact: "Potential crop losses and increased treatment costs"
    });
  }
  
  // Weather risks
  if (weatherRisk === 'High') {
    risks.push({
      factor: "Weather Stress",
      severity: "High",
      description: "Environmental conditions create weather stress",
      impact: "Reduced plant vigor and yield"
    });
  }
  
  // Budget risks
  const budgetRatio = budget / totalCosts;
  if (budgetRatio < 1.0) {
    risks.push({
      factor: "Budget Shortfall",
      severity: budgetRatio < 0.8 ? "High" : "Medium",
      description: `Need $${(totalCosts - budget).toFixed(0)} more (${((1-budgetRatio)*100).toFixed(1)}% short)`,
      impact: "May need to reduce inputs or farm size"
    });
  }
  
  return risks;
}

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send("Something went wrong!");
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
