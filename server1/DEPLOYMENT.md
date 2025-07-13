# Eco-Farming API - Vercel Deployment Instructions

This project has been converted from an Express.js server to a Vercel-compatible serverless architecture.

## 🚀 Quick Deploy

### 1. Install Dependencies
```bash
npm install
```

### 2. Environment Variables
Create a `.env.local` file in the root directory with your API keys:
```
API_KEY=your_waqi_api_key_here
SECOND_API_KEY=your_openweather_api_key_here
GEMINI_API_KEY=your_google_gemini_api_key_here
```

### 3. Deploy to Vercel
1. Install Vercel CLI: `npm i -g vercel`
2. Login to Vercel: `vercel login`
3. Deploy: `vercel --prod`

## 🔧 Local Development
```bash
npm run dev
# or
vercel dev
```

## 📁 Project Structure
```
/
├── api/                    # Serverless functions
│   ├── eco-score.js       # GET /api/eco-score
│   ├── eco-challenge.js   # GET /api/eco-challenge
│   ├── eco-action.js      # POST /api/eco-action
│   ├── eco-rewards.js     # GET /api/eco-rewards
│   ├── eco-impact.js      # GET /api/eco-impact
│   ├── register.js        # POST /api/register
│   ├── login.js           # POST /api/login
│   ├── countries.js       # GET /api/countries
│   ├── cities.js          # GET /api/cities
│   ├── aqi.js             # GET /api/aqi
│   ├── weather.js         # GET /api/weather
│   ├── plant-names.js     # GET /api/plant-names
│   └── ai-chat.js         # POST /api/ai-chat
├── lib/
│   └── utils.js           # Shared utility functions
├── package.json           # Dependencies
├── vercel.json            # Vercel configuration
└── DEPLOYMENT.md          # This file
```

## 🛠️ API Endpoints

### Eco System
- `GET /api/eco-score?username=user` - Get user's eco score
- `GET /api/eco-challenge` - Get random eco challenge
- `POST /api/eco-action` - Submit eco action
- `GET /api/eco-rewards?username=user` - Get user rewards
- `GET /api/eco-impact?username=user` - Get environmental impact

### Authentication
- `POST /api/register` - Register new user
- `POST /api/login` - User login

### Location & Weather
- `GET /api/countries` - Get all countries
- `GET /api/cities?country=CountryName` - Get cities by country
- `GET /api/weather?city=CityName` - Get weather data
- `GET /api/aqi?city=CityName` - Get air quality data

### Agriculture
- `GET /api/plant-names` - Get available plant names
- `POST /api/ai-chat` - AI farming advisor

## 🔑 Required API Keys

1. **WAQI API Key** (`API_KEY`): Get from [World Air Quality Index](https://aqicn.org/api/)
2. **OpenWeather API Key** (`SECOND_API_KEY`): Get from [OpenWeatherMap](https://openweathermap.org/api)
3. **Google Gemini API Key** (`GEMINI_API_KEY`): Get from [Google AI Studio](https://ai.google.dev/)

## 📝 Environment Variables Setup in Vercel

1. Go to your Vercel dashboard
2. Select your project
3. Go to Settings → Environment Variables
4. Add the following variables:
   - `API_KEY` (WAQI API key)
   - `SECOND_API_KEY` (OpenWeather API key)
   - `GEMINI_API_KEY` (Google Gemini API key)

## 🔧 CORS Configuration

The API is configured to allow requests from any origin (`*`). If you need to restrict access, modify the CORS headers in each API endpoint file.

## 🚨 Important Notes

- The current implementation uses in-memory storage which will reset on each deployment
- For production, consider using a database (MongoDB, PostgreSQL, etc.)
- Rate limiting is handled by the respective API providers
- Some endpoints may need additional error handling for production use

## 📊 Usage Examples

### Get Eco Score
```javascript
fetch('/api/eco-score?username=john')
  .then(res => res.json())
  .then(data => console.log(data.score));
```

### Chat with AI
```javascript
fetch('/api/ai-chat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ message: 'How do I grow tomatoes?' })
})
.then(res => res.json())
.then(data => console.log(data.response));
```

### Get Weather
```javascript
fetch('/api/weather?city=London')
  .then(res => res.json())
  .then(data => console.log(data));
```

## 🎯 Ready for Production

Your API is now ready for deployment! Simply run `vercel --prod` and your serverless functions will be live.

Remember to:
1. Set up your environment variables in Vercel
2. Test all endpoints after deployment
3. Monitor your API usage and rate limits
4. Consider implementing authentication for production use 