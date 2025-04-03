const express = require('express');
const dotenv = require('dotenv');
const cors = require('cors');
const pool = require('./config/db'); // Import db connection pool

// Load Env Vars
dotenv.config();

const app = express();

// Body Parser Middleware
app.use(express.json()); 
app.use(express.urlencoded({ extended: false }));

// Enable CORS
// TODO: Configure CORS more restrictively for production
app.use(cors());

// Simple Route for Testing
app.get('/', (req, res) => {
  res.send('Moodly API running...');
});

// --- Mount Routers --- 
app.use('/api/v1/auth', require('./routes/auth')); // Mount auth routes
app.use('/api/v1/moods', require('./routes/moods')); // Mount mood routes
// Example: app.use('/api/v1/moods', require('./routes/moods'));
// TODO: Create and mount mood routes later

const PORT = process.env.PORT || 3000;

const server = app.listen(
  PORT,
  console.log(`Server running on port ${PORT}`)
);

// Handle unhandled promise rejections
process.on('unhandledRejection', (err, promise) => {
  console.log(`Error: ${err.message}`);
  // Close server & exit process
  server.close(() => process.exit(1));
}); 