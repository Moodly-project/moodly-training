const express = require('express');
const {
    register,
    login,
    // getMe 
} = require('../controllers/authController');

// TODO: Add auth middleware (protect routes)
// const { protect } = require('../middleware/auth'); 

const router = express.Router();

router.post('/register', register);
router.post('/login', login);
// router.get('/me', protect, getMe); 

module.exports = router; 