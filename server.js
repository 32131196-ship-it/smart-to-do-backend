// server.js - Node.js Backend with Express and MySQL
const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();
const PORT = 3001;

// Middleware
app.use(cors());
app.use(bodyParser.json());

// MySQL Connection Pool
const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: '', 
  database: 'smart_todo',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Initialize database main table if not exist 
async function initDatabase() {
  try {
    const connection = await pool.getConnection();
    
    // Create tasks table
    await connection.query(`
      CREATE TABLE IF NOT EXISTS tasks (
        id VARCHAR(255) PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        priority ENUM('low', 'medium', 'high') DEFAULT 'medium',
        status ENUM('pending', 'completed') DEFAULT 'pending',
        due_date DATE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);
    
    console.log('Database tables initialized');
    connection.release();
  } catch (error) {
    console.error('Database initialization error:', error);
  }
}

initDatabase();

// API Routes

// Get all tasks
app.get('/api/tasks', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM tasks ORDER BY created_at DESC');
    res.json(rows);
  } catch (error) {
    console.error('Error fetching tasks:', error);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// Get single task by ID
app.get('/api/tasks/:id', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM tasks WHERE id = ?', [req.params.id]);
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }
    res.json(rows[0]);
  } catch (error) {
    console.error('Error fetching task:', error);
    res.status(500).json({ error: 'Failed to fetch task' });
  }
});

// Create new task
app.post('/api/tasks', async (req, res) => {
  try {
    const { id, title, description, priority, status, due_date } = req.body;
    
    if (!title) {
      return res.status(400).json({ error: 'Title is required' });
    }
    
    const taskId = id || Date.now().toString();
    
    await pool.query(
      'INSERT INTO tasks (id, title, description, priority, status, due_date) VALUES (?, ?, ?, ?, ?, ?)',
      [taskId, title, description || null, priority || 'medium', status || 'pending', due_date || null]
    );
    
    const [rows] = await pool.query('SELECT * FROM tasks WHERE id = ?', [taskId]);
    res.status(201).json(rows[0]);
  } catch (error) {
    console.error('Error creating task:', error);
    res.status(500).json({ error: 'Failed to create task' });
  }
});

// Update task
app.put('/api/tasks/:id', async (req, res) => {
  try {
    const { title, description, priority, status, due_date } = req.body;
    const { id } = req.params;
    
    const [result] = await pool.query(
      `UPDATE tasks 
       SET title = COALESCE(?, title),
           description = COALESCE(?, description),
           priority = COALESCE(?, priority),
           status = COALESCE(?, status),
           due_date = COALESCE(?, due_date)
       WHERE id = ?`,
      [title, description, priority, status, due_date, id]
    );
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    const [rows] = await pool.query('SELECT * FROM tasks WHERE id = ?', [id]);
    res.json(rows[0]);
  } catch (error) {
    console.error('Error updating task:', error);
    res.status(500).json({ error: 'Failed to update task' });
  }
});

// Delete task
app.delete('/api/tasks/:id', async (req, res) => {
  try {
    const [result] = await pool.query('DELETE FROM tasks WHERE id = ?', [req.params.id]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    res.json({ message: 'Task deleted successfully' });
  } catch (error) {
    console.error('Error deleting task:', error);
    res.status(500).json({ error: 'Failed to delete task' });
  }
});

// Get tasks by priority
app.get('/api/tasks/priority/:priority', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM tasks WHERE priority = ? ORDER BY created_at DESC',
      [req.params.priority]
    );
    res.json(rows);
  } catch (error) {
    console.error('Error fetching tasks by priority:', error);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// Get tasks by status
app.get('/api/tasks/status/:status', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM tasks WHERE status = ? ORDER BY created_at DESC',
      [req.params.status]
    );
    res.json(rows);
  } catch (error) {
    console.error('Error fetching tasks by status:', error);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// Get tasks by date range
app.get('/api/tasks/date-range', async (req, res) => {
  try {
    const { start_date, end_date } = req.query;
    
    if (!start_date || !end_date) {
      return res.status(400).json({ error: 'Start date and end date are required' });
    }
    
    const [rows] = await pool.query(
      'SELECT * FROM tasks WHERE due_date BETWEEN ? AND ? ORDER BY due_date',
      [start_date, end_date]
    );
    res.json(rows);
  } catch (error) {
    console.error('Error fetching tasks by date range:', error);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// Search tasks
app.get('/api/tasks/search', async (req, res) => {
  try {
    const { q } = req.query;
    
    if (!q) {
      return res.status(400).json({ error: 'Search query is required' });
    }
    
    const [rows] = await pool.query(
      'SELECT * FROM tasks WHERE title LIKE ? OR description LIKE ? ORDER BY created_at DESC',
      [`%${q}%`, `%${q}%`]
    );
    res.json(rows);
  } catch (error) {
    console.error('Error searching tasks:', error);
    res.status(500).json({ error: 'Failed to search tasks' });
  }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'Server is running' });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
  console.log(`API endpoints available at http://localhost:${PORT}/api`);
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('Shutting down gracefully...');
  await pool.end();
  process.exit(0);
});