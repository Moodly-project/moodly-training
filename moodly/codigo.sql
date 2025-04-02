CREATE DATABASE moodly_db;


-- Tabela de Usuários
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL, -- Store hashed password
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de Entradas de Humor
CREATE TABLE mood_entries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    mood VARCHAR(50) NOT NULL, -- Consider using ENUM later if moods are fixed
    notes TEXT NULL,
    entry_date TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE -- Link to users table
);

-- Opcional: Índice para consultas mais rápidas
CREATE INDEX idx_user_date ON mood_entries (user_id, entry_date DESC);

select * from users
select * from mood_entries