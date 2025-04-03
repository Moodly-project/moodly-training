const express = require('express');
const {
  getMoodEntries,
  addMoodEntry,
  updateMoodEntry,
  deleteMoodEntry,
} = require('../controllers/moodController');

const { protect } = require('../middleware/auth'); // Import protect middleware

const router = express.Router();

// Apply protect middleware to all routes in this file
router.use(protect);

// Define routes
router.route('/').get(getMoodEntries).post(addMoodEntry);

router.route('/:id').put(updateMoodEntry).delete(deleteMoodEntry);

module.exports = router; 