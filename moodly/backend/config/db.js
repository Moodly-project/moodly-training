const mysql = require('mysql2/promise');
const dotenv = require('dotenv');

dotenv.config();

// DB Connection Pool
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '', // Ensure this is set in .env
  database: process.env.DB_NAME || 'moodly_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Test Connection
pool.getConnection()
  .then(connection => {
    console.log('DB connected.');
    connection.release();
  })
  .catch(err => {
    console.error('DB connection error:', err);
    // process.exit(1); // Optional: Exit if critical
  });

module.exports = pool; 