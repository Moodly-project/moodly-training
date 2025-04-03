const jwt = require('jsonwebtoken');
const pool = require('../config/db');

// Protect routes
exports.protect = async (req, res, next) => {
  let token;

  // Check for token in Authorization header (Bearer token)
  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer')
  ) {
    token = req.headers.authorization.split(' ')[1];
  }
  // Optional: Check for token in cookies if implementing web sessions later
  // else if (req.cookies.token) { 
  //   token = req.cookies.token; 
  // }

  // Make sure token exists
  if (!token) {
    return res.status(401).json({ success: false, message: 'Not authorized to access this route (no token)' });
  }

  try {
    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Fetch user details based on token payload (id)
    const [users] = await pool.query('SELECT id, name, email FROM users WHERE id = ?', [decoded.id]);

    if (users.length === 0) {
       return res.status(401).json({ success: false, message: 'User not found, invalid token?' });
    }

    // Attach user to the request object
    req.user = users[0];
    next(); // Proceed to the next middleware/controller

  } catch (err) {
    console.error('Token verification error:', err);
    return res.status(401).json({ success: false, message: 'Not authorized to access this route (token failed)' });
  }
};

// TODO: Grant access to specific roles (if needed later)
// exports.authorize = (...roles) => { ... } 