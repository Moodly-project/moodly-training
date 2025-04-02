const pool = require('../config/db');

// @desc    Get all mood entries for the logged-in user
// @route   GET /api/v1/moods
// @access  Private
exports.getMoodEntries = async (req, res, next) => {
  try {
    // User ID is available from the protect middleware (req.user.id)
    const [entries] = await pool.query(
      'SELECT * FROM mood_entries WHERE user_id = ? ORDER BY entry_date DESC',
      [req.user.id]
    );

    res.status(200).json({ success: true, count: entries.length, data: entries });
  } catch (error) {
    console.error('Get Moods Error:', error);
    res.status(500).json({ success: false, message: 'Server Error fetching moods' });
  }
};

// @desc    Add a new mood entry for the logged-in user
// @route   POST /api/v1/moods
// @access  Private
exports.addMoodEntry = async (req, res, next) => {
  const { mood, notes, entry_date } = req.body;

  if (!mood || !entry_date) {
    return res.status(400).json({ success: false, message: 'Humor e data são obrigatórios' });
  }

  try {
    // Convert ISO string to MySQL DATETIME format (YYYY-MM-DD HH:MM:SS)
    const formattedDate = new Date(entry_date).toISOString().slice(0, 19).replace('T', ' ');

    const entryData = {
      user_id: req.user.id,
      mood,
      notes: notes || null, 
      entry_date: formattedDate // Use formatted date
    };

    const [result] = await pool.query('INSERT INTO mood_entries SET ?', entryData);

    // Fetch the newly created entry to return it
    const [newEntry] = await pool.query('SELECT * FROM mood_entries WHERE id = ?', [result.insertId]);

    res.status(201).json({ success: true, data: newEntry[0] });

  } catch (error) {
    console.error('Add Mood Error:', error);
    // Check for specific date conversion error
    if (error instanceof RangeError || error.message.includes('Invalid time value')) {
        return res.status(400).json({ success: false, message: 'Formato de data inválido recebido.' });
    }
    res.status(500).json({ success: false, message: 'Erro servidor add humor' });
  }
};

// @desc    Update a specific mood entry
// @route   PUT /api/v1/moods/:id
// @access  Private
exports.updateMoodEntry = async (req, res, next) => {
  const { mood, notes, entry_date } = req.body;
  const entryId = req.params.id;

  if (!mood && !notes && !entry_date) {
     return res.status(400).json({ success: false, message: 'Nenhum campo para atualizar' });
  }

  try {
    const [entries] = await pool.query(
      'SELECT * FROM mood_entries WHERE id = ? AND user_id = ?',
      [entryId, req.user.id]
    );

    if (entries.length === 0) {
      return res.status(404).json({ success: false, message: `Entrada ${entryId} não encontrada ou não autorizada` });
    }

    const updateFields = {};
    if (mood) updateFields.mood = mood;
    if (notes !== undefined) updateFields.notes = notes;
    if (entry_date) {
      // Format date if provided for update
       try {
          updateFields.entry_date = new Date(entry_date).toISOString().slice(0, 19).replace('T', ' ');
       } catch (e) {
          return res.status(400).json({ success: false, message: 'Formato de data inválido para atualização.' });
       }
    }

    await pool.query('UPDATE mood_entries SET ? WHERE id = ?', [updateFields, entryId]);

    const [updatedEntry] = await pool.query('SELECT * FROM mood_entries WHERE id = ?', [entryId]);
    res.status(200).json({ success: true, data: updatedEntry[0] });

  } catch (error) {
    console.error('Update Mood Error:', error);
    res.status(500).json({ success: false, message: 'Erro servidor update humor' });
  }
};

// @desc    Delete a specific mood entry
// @route   DELETE /api/v1/moods/:id
// @access  Private
exports.deleteMoodEntry = async (req, res, next) => {
  const entryId = req.params.id;

  try {
    // Check if entry exists and belongs to the user before deleting
    const [entries] = await pool.query(
      'SELECT id FROM mood_entries WHERE id = ? AND user_id = ?',
      [entryId, req.user.id]
    );

    if (entries.length === 0) {
      return res.status(404).json({ success: false, message: `Mood entry not found with id ${entryId} or not authorized` });
    }

    // Perform delete
    await pool.query('DELETE FROM mood_entries WHERE id = ?', [entryId]);

    res.status(200).json({ success: true, data: {} }); // Return empty object on successful delete

  } catch (error) {
    console.error('Delete Mood Error:', error);
    res.status(500).json({ success: false, message: 'Server Error deleting mood' });
  }
}; 