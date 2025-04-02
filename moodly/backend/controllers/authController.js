const pool = require('../config/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const dotenv = require('dotenv');

dotenv.config();

// Register user (POST /api/v1/auth/register)
exports.register = async (req, res, next) => {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
        return res.status(400).json({ success: false, message: 'Nome, email, senha necessários' });
    }
    if (password.length < 6) {
         return res.status(400).json({ success: false, message: 'Senha >= 6 chars' });
    }

    try {
        const [existingUsers] = await pool.query('SELECT email FROM users WHERE email = ?', [email]);
        if (existingUsers.length > 0) {
            return res.status(400).json({ success: false, message: 'Email já existe' });
        }

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        await pool.query(
            'INSERT INTO users (name, email, password) VALUES (?, ?, ?)',
            [name, email, hashedPassword]
        );

        res.status(201).json({ success: true, message: 'Usuário registrado' });

    } catch (error) {
        console.error('Register Error:', error);
        res.status(500).json({ success: false, message: 'Erro servidor (registro)' });
    }
};

// Login user (POST /api/v1/auth/login)
exports.login = async (req, res, next) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ success: false, message: 'Email e senha necessários' });
    }

    try {
        const [users] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
        if (users.length === 0) {
            return res.status(401).json({ success: false, message: 'Credenciais inválidas' });
        }

        const user = users[0];
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(401).json({ success: false, message: 'Credenciais inválidas' });
        }

        const payload = { id: user.id };
        const token = jwt.sign(payload, process.env.JWT_SECRET, {
            expiresIn: process.env.JWT_EXPIRES_IN || '1d',
        });

        res.status(200).json({
            success: true,
            token: token,
            user: { id: user.id, name: user.name, email: user.email }
        });

    } catch (error) {
        console.error('Login Error:', error);
        res.status(500).json({ success: false, message: 'Erro servidor (login)' });
    }
};

// TODO: getMe controller

// TODO: Add getMe controller (requires authentication middleware)
// exports.getMe = async (req, res, next) => { ... }; 